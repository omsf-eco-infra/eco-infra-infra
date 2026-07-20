#!/usr/bin/env python3
"""Generate root provider requirements from a compatibility consumer graph."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any


class GenerationError(RuntimeError):
    """A provider requirement cannot be inspected or converted safely."""


BUILTIN_PROVIDER_SOURCES = {"terraform.io/builtin/terraform"}


@dataclass(frozen=True, order=True)
class Version:
    major: int
    minor: int
    patch: int

    @classmethod
    def parse(cls, value: str) -> Version:
        if not re.fullmatch(r"\d+(?:\.\d+){0,2}", value):
            raise GenerationError(
                f"unsupported version {value!r}; expected one to three numeric components"
            )
        components = [int(component) for component in value.split(".")]
        components.extend([0] * (3 - len(components)))
        return cls(*components)

    def __str__(self) -> str:
        return f"{self.major}.{self.minor}.{self.patch}"


@dataclass(frozen=True)
class ProviderRequirement:
    local_name: str
    source: str
    constraint: str
    module: Path


@dataclass(frozen=True)
class GeneratedProvider:
    local_name: str
    source: str
    minimum: Version


@dataclass(frozen=True)
class Constraint:
    operator: str
    version: Version
    component_count: int


def parse_constraint(constraint: str) -> list[Constraint]:
    if not constraint.strip():
        raise GenerationError("provider requirement has no version constraint")

    parsed: list[Constraint] = []
    for condition in constraint.split(","):
        match = re.fullmatch(
            r"\s*(?P<operator>~>|>=|<=|!=|>|<|=)?\s*"
            r"(?P<version>\d+(?:\.\d+){0,2})\s*",
            condition,
        )
        if match is None:
            raise GenerationError(f"unsupported version condition {condition.strip()!r}")

        operator = match.group("operator") or "="
        version_text = match.group("version")
        if operator in {">", "!="}:
            raise GenerationError(
                f"condition {condition.strip()!r} has no statically derivable minimum"
            )
        parsed.append(
            Constraint(operator, Version.parse(version_text), len(version_text.split(".")))
        )

    exact = [condition for condition in parsed if condition.operator == "="]
    if exact and len(parsed) != 1:
        raise GenerationError("an exact version cannot be combined with other conditions")
    return parsed


def pessimistic_upper_bound(condition: Constraint) -> Version:
    version = condition.version
    if condition.component_count == 1:
        return Version(version.major + 1, 0, 0)
    if condition.component_count == 2:
        return Version(version.major + 1, 0, 0)
    return Version(version.major, version.minor + 1, 0)


def minimum_for_constraint(constraint: str) -> Version:
    conditions = parse_constraint(constraint)
    lower_bounds = [
        condition.version
        for condition in conditions
        if condition.operator in {"=", ">=", "~>"}
    ]
    if not lower_bounds:
        raise GenerationError(
            f"constraint {constraint!r} does not declare an inclusive lower bound"
        )

    minimum = max(lower_bounds)
    for condition in conditions:
        if condition.operator == "<" and not minimum < condition.version:
            raise GenerationError(f"constraint {constraint!r} has an empty version range")
        if condition.operator == "<=" and not minimum <= condition.version:
            raise GenerationError(f"constraint {constraint!r} has an empty version range")
        if condition.operator == "~>" and not minimum < pessimistic_upper_bound(condition):
            raise GenerationError(f"constraint {constraint!r} has an empty version range")
    return minimum


def constraint_allows(constraint: str, version: Version) -> bool:
    for condition in parse_constraint(constraint):
        if condition.operator == "=" and version != condition.version:
            return False
        if condition.operator == ">=" and version < condition.version:
            return False
        if condition.operator == "<" and version >= condition.version:
            return False
        if condition.operator == "<=" and version > condition.version:
            return False
        if condition.operator == "~>" and not (
            version >= condition.version
            and version < pessimistic_upper_bound(condition)
        ):
            return False
    return True


class OpenTofuInspector:
    def __init__(self, executable: str = "tofu") -> None:
        self.executable = executable

    def inspect(self, module: Path) -> dict[str, Any]:
        command = [self.executable, "show", f"-module={module}", "-json"]
        try:
            result = subprocess.run(
                command,
                check=False,
                capture_output=True,
                text=True,
            )
        except OSError as error:
            raise GenerationError(
                f"could not execute OpenTofu inspector {self.executable!r}: {error}"
            ) from error

        if result.returncode != 0:
            detail = result.stderr.strip() or result.stdout.strip() or "unknown error"
            raise GenerationError(f"could not inspect {module}: {detail}")
        try:
            document = json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise GenerationError(
                f"OpenTofu returned invalid JSON for {module}: {error}"
            ) from error
        if not isinstance(document, dict):
            raise GenerationError(f"OpenTofu returned an invalid document for {module}")
        return document


def local_module_sources(document: dict[str, Any], module: Path) -> list[Path]:
    root_module = document.get("root_module") or {}
    module_calls = root_module.get("module_calls") or {}
    sources: list[Path] = []
    for name, call in module_calls.items():
        if not isinstance(call, dict):
            raise GenerationError(f"module call {name!r} in {module} is invalid")
        source = call.get("source")
        if not isinstance(source, str):
            raise GenerationError(f"module call {name!r} in {module} has no static source")
        if not source.startswith(("./", "../")):
            raise GenerationError(
                f"module call {name!r} in {module} uses non-local source {source!r}"
            )
        resolved = (module / source).resolve()
        if not resolved.is_dir():
            raise GenerationError(
                f"module call {name!r} in {module} resolves to missing directory {resolved}"
            )
        sources.append(resolved)
    return sources


def module_provider_requirements(
    document: dict[str, Any], module: Path
) -> list[ProviderRequirement]:
    provider_config = document.get("provider_config") or {}
    requirements: list[ProviderRequirement] = []
    for local_name, provider in provider_config.items():
        if not isinstance(provider, dict):
            raise GenerationError(f"provider {local_name!r} in {module} is invalid")
        source = provider.get("full_name")
        constraint = provider.get("version_constraint")
        if not isinstance(source, str) or not source:
            raise GenerationError(f"provider {local_name!r} in {module} has no source")
        if source in BUILTIN_PROVIDER_SOURCES:
            continue
        if not isinstance(constraint, str) or not constraint:
            raise GenerationError(
                f"provider {source!r} in {module} has no minimum version constraint"
            )
        requirements.append(
            ProviderRequirement(local_name, source, constraint, module)
        )
    return requirements


def collect_requirements(
    fixture: Path, inspector: OpenTofuInspector
) -> list[ProviderRequirement]:
    pending = [fixture.resolve()]
    visited: set[Path] = set()
    requirements: list[ProviderRequirement] = []

    while pending:
        module = pending.pop()
        if module in visited:
            continue
        visited.add(module)
        document = inspector.inspect(module)
        requirements.extend(module_provider_requirements(document, module))
        pending.extend(local_module_sources(document, module))
    return requirements


def combine_requirements(
    requirements: list[ProviderRequirement],
) -> list[GeneratedProvider]:
    by_name: dict[str, list[ProviderRequirement]] = {}
    for requirement in requirements:
        by_name.setdefault(requirement.local_name, []).append(requirement)

    generated: list[GeneratedProvider] = []
    for local_name, declarations in sorted(by_name.items()):
        sources = {declaration.source for declaration in declarations}
        if len(sources) != 1:
            details = ", ".join(sorted(sources))
            raise GenerationError(
                f"local provider name {local_name!r} maps to multiple sources: {details}"
            )
        minimum = max(
            minimum_for_constraint(declaration.constraint)
            for declaration in declarations
        )
        incompatible = [
            declaration
            for declaration in declarations
            if not constraint_allows(declaration.constraint, minimum)
        ]
        if incompatible:
            details = ", ".join(
                f"{declaration.module}: {declaration.constraint}"
                for declaration in declarations
            )
            raise GenerationError(
                f"provider {local_name!r} has incompatible constraints: {details}"
            )
        generated.append(GeneratedProvider(local_name, sources.pop(), minimum))
    return generated


def display_source(source: str) -> str:
    prefix = "registry.opentofu.org/"
    return source.removeprefix(prefix)


def render_providers(providers: list[GeneratedProvider], profile: str) -> str:
    if profile not in {"minimum", "latest"}:
        raise GenerationError(f"unknown provider profile {profile!r}")
    if not providers:
        raise GenerationError("consumer graph declares no providers")

    lines = ["terraform {", "  required_providers {"]
    for index, provider in enumerate(providers):
        if index:
            lines.append("")
        lines.extend(
            [
                f"    {provider.local_name} = {{",
                f'      source  = "{display_source(provider.source)}"'
                if profile == "minimum"
                else f'      source = "{display_source(provider.source)}"',
            ]
        )
        if profile == "minimum":
            lines.append(f'      version = "= {provider.minimum}"')
        lines.append("    }")
    lines.extend(["  }", "}", ""])
    return "\n".join(lines)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", required=True, type=Path)
    parser.add_argument("--profile", required=True, choices=("minimum", "latest"))
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument(
        "--tofu",
        default=os.environ.get("TOFU_INSPECT", "tofu"),
        help="OpenTofu 1.11+ executable used for static module inspection",
    )
    return parser


def main(argv: list[str] | None = None) -> int:
    arguments = build_parser().parse_args(argv)
    try:
        requirements = collect_requirements(
            arguments.fixture, OpenTofuInspector(arguments.tofu)
        )
        providers = combine_requirements(requirements)
        rendered = render_providers(providers, arguments.profile)
        arguments.output.parent.mkdir(parents=True, exist_ok=True)
        arguments.output.write_text(rendered)
    except GenerationError as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
