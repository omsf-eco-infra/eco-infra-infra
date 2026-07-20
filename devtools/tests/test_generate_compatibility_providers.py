from __future__ import annotations

import json
from pathlib import Path
from subprocess import CompletedProcess

import pytest

from devtools.generate_compatibility_providers import (
    GeneratedProvider,
    GenerationError,
    OpenTofuInspector,
    ProviderRequirement,
    Version,
    collect_requirements,
    combine_requirements,
    minimum_for_constraint,
    module_provider_requirements,
    render_providers,
)


REPOSITORY_ROOT = Path(__file__).parents[2]


@pytest.mark.parametrize(
    ("constraint", "expected"),
    [
        (">= 6.12.0", Version(6, 12, 0)),
        (">= 4.2.0, < 5.0.0", Version(4, 2, 0)),
        ("~> 4.0", Version(4, 0, 0)),
        ("~> 4.2.3", Version(4, 2, 3)),
        ("= 5.14.0", Version(5, 14, 0)),
        ("5.14", Version(5, 14, 0)),
        (">= 4.0.0, >= 4.2.0", Version(4, 2, 0)),
    ],
)
def test_minimum_for_constraint(constraint: str, expected: Version) -> None:
    assert minimum_for_constraint(constraint) == expected


@pytest.mark.parametrize(
    "constraint",
    [
        "",
        "< 5.0.0",
        "> 4.0.0",
        ">= 4.0.0, != 4.0.0",
        ">= 5.0.0, < 5.0.0",
        "= 4.0.0, < 5.0.0",
        ">= 4.0.0-beta.1",
    ],
)
def test_minimum_rejects_ambiguous_or_invalid_constraints(constraint: str) -> None:
    with pytest.raises(GenerationError):
        minimum_for_constraint(constraint)


def test_combine_requirements_uses_greatest_floor() -> None:
    requirements = [
        ProviderRequirement(
            "aws",
            "registry.opentofu.org/hashicorp/aws",
            "~> 4.0",
            Path("permissions"),
        ),
        ProviderRequirement(
            "aws",
            "registry.opentofu.org/hashicorp/aws",
            ">= 4.2.0, < 5.0.0",
            Path("module"),
        ),
        ProviderRequirement(
            "github",
            "registry.opentofu.org/integrations/github",
            ">= 6.12.0",
            Path("module"),
        ),
    ]

    assert combine_requirements(requirements) == [
        GeneratedProvider("aws", "registry.opentofu.org/hashicorp/aws", Version(4, 2, 0)),
        GeneratedProvider(
            "github", "registry.opentofu.org/integrations/github", Version(6, 12, 0)
        ),
    ]


def test_combine_rejects_conflicting_sources() -> None:
    requirements = [
        ProviderRequirement("cloud", "example/a", ">= 1.0.0", Path("a")),
        ProviderRequirement("cloud", "example/b", ">= 1.0.0", Path("b")),
    ]

    with pytest.raises(GenerationError, match="multiple sources"):
        combine_requirements(requirements)


def test_combine_rejects_incompatible_ranges() -> None:
    requirements = [
        ProviderRequirement("aws", "hashicorp/aws", "~> 4.0", Path("a")),
        ProviderRequirement("aws", "hashicorp/aws", ">= 5.0.0", Path("b")),
    ]

    with pytest.raises(GenerationError, match="incompatible constraints"):
        combine_requirements(requirements)


def test_render_minimum_profile() -> None:
    rendered = render_providers(
        [
            GeneratedProvider(
                "aws", "registry.opentofu.org/hashicorp/aws", Version(4, 2, 0)
            )
        ],
        "minimum",
    )

    assert rendered == """terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 4.2.0"
    }
  }
}
"""


def test_render_latest_profile_omits_version() -> None:
    rendered = render_providers(
        [
            GeneratedProvider(
                "github",
                "registry.opentofu.org/integrations/github",
                Version(6, 12, 0),
            )
        ],
        "latest",
    )

    assert 'source = "integrations/github"' in rendered
    assert "version" not in rendered


def test_builtin_provider_is_ignored() -> None:
    document = {
        "provider_config": {
            "terraform": {
                "full_name": "terraform.io/builtin/terraform",
            }
        }
    }

    assert module_provider_requirements(document, Path("module")) == []


class FakeInspector:
    def __init__(self, documents: dict[str, dict]) -> None:
        self.documents = documents
        self.visited: list[str] = []

    def inspect(self, module: Path) -> dict:
        self.visited.append(module.name)
        return self.documents[module.name]


def test_collect_requirements_recurses_and_deduplicates(tmp_path: Path) -> None:
    fixture = tmp_path / "fixture"
    child = tmp_path / "child"
    fixture.mkdir()
    child.mkdir()
    inspector = FakeInspector(
        {
            "fixture": {
                "root_module": {
                    "module_calls": {
                        "first": {"source": "../child"},
                        "second": {"source": "../child"},
                    }
                }
            },
            "child": {
                "provider_config": {
                    "aws": {
                        "full_name": "registry.opentofu.org/hashicorp/aws",
                        "version_constraint": ">= 4.0.0",
                    }
                },
                "root_module": {},
            },
        }
    )

    requirements = collect_requirements(fixture, inspector)  # type: ignore[arg-type]

    assert len(requirements) == 1
    assert sorted(inspector.visited) == ["child", "fixture"]


def test_inspector_reports_command_error(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_run(*args, **kwargs):
        return CompletedProcess(args[0], 1, "", "unsupported command")

    monkeypatch.setattr("subprocess.run", fake_run)

    with pytest.raises(GenerationError, match="unsupported command"):
        OpenTofuInspector("tofu-inspect").inspect(Path("module"))


def test_inspector_parses_json(monkeypatch: pytest.MonkeyPatch) -> None:
    document = {"provider_config": {}}

    def fake_run(*args, **kwargs):
        return CompletedProcess(args[0], 0, json.dumps(document), "")

    monkeypatch.setattr("subprocess.run", fake_run)

    assert OpenTofuInspector().inspect(Path("module")) == document


@pytest.mark.parametrize(
    ("fixture", "expected"),
    [
        ("github-oidc", {"aws": "4.0.0"}),
        (
            "internal-github-actions-aws-role",
            {"aws": "4.2.0", "github": "6.12.0"},
        ),
        ("repo-oidc-customization", {"github": "5.14.0"}),
        ("tfstate-aws-backend", {"aws": "4.0.0"}),
    ],
)
def test_repository_fixture_floors(
    fixture: str, expected: dict[str, str]
) -> None:
    fixture_path = REPOSITORY_ROOT / "tests" / "compatibility" / "fixtures" / fixture

    providers = combine_requirements(
        collect_requirements(fixture_path, OpenTofuInspector())
    )

    assert {provider.local_name: str(provider.minimum) for provider in providers} == expected
