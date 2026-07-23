# Adding Modules

This guide describes the repository work required to add a reusable
infrastructure module. A module is complete only when its public interface,
documentation, permission model, contract coverage, and compatibility coverage
are all represented in the repository.

## Choose the module location

Add modules intended for direct use under `modules/<name>`. Add implementation
building blocks under `modules/internal/<name>`.

Add the module to the appropriate section of the root [README](README.md). Its
own README should describe:

- its purpose and the resources it manages;
- OpenTofu and provider requirements;
- inputs and outputs;
- a usable example; and
- relevant security, lifecycle, and operational considerations.

## Add the module files

A typical module contains:

| File | Purpose |
| --- | --- |
| `main.tf` | Resources, data sources, and local values |
| `variables.tf` | Public inputs and their validation |
| `outputs.tf` | Public results consumed by callers or other modules |
| `providers.tf` | Provider sources and supported version ranges |
| `versions.tofu` | The repository-wide OpenTofu version floor |
| `README.md` | Public requirements, interface, examples, and operational notes |
| `main.tftest.hcl` | Credential-free module tests |

Do not add empty files when a module genuinely has no variables, outputs, or
provider dependencies.

Reusable module directories must not commit `.terraform.lock.hcl`. Provider
lock files belong to the root configuration consuming a module. Repository
tests create temporary lock files and discard them.

## Follow the compatibility policy

The repository-wide minimum supported OpenTofu version is **1.10.0**. Every
committed module, deploy-permissions companion, contract root, and compatibility
root must contain `versions.tofu` with:

```hcl
terraform {
  required_version = ">= 1.10.0"
}
```

In `providers.tf`, declare the oldest provider version the module is known to
support. Do not infer a floor from the version used during development: verify
the floor through the compatibility fixture described below.

### Repository-wide provider upper bounds

| Provider | Allowed range | Required constraint style | Applies to |
| --- | --- | --- | --- |
| `hashicorp/aws` | AWS 4.x only (`< 5.0.0`) | `~> 4.0` or `>= <floor>, < 5.0.0` | Bootstrap, modules, deploy-permissions modules, and test roots |

There are currently no other provider upper bounds in the tracked repository.
In particular, the GitHub provider has module-specific minimums but no
repository-wide maximum.

When introducing another provider upper bound, add a row to this table in the
same change. Apply the bound consistently to affected modules,
deploy-permissions companions, contract roots, compatibility fixtures,
examples, and provider documentation.

Changing the OpenTofu floor or a provider upper bound is an intentional
repository compatibility-policy change and should be called out explicitly in
the pull request.

## Add module-local tests

Add credential-free tests in `main.tftest.hcl`. Use mocked providers and cover,
as applicable:

- important resource configuration and lifecycle behavior;
- public outputs;
- significant input combinations; and
- validation failures with useful error messages.

Add the module directory to `MODULE_TEST_DIRECTORIES` in
`.github/workflows/tests.yaml`. The fast-test job initializes, validates, and
runs `tofu test` for every directory in that list using the latest OpenTofu and
latest-compatible providers.

Run the module tests locally:

```console
tofu -chdir=modules/<name> init -backend=false
tofu -chdir=modules/<name> validate
tofu -chdir=modules/<name> test
```

Use `modules/internal/<name>` in those commands for an internal module.

## Add deploy permissions and contract tests

An AWS infrastructure module must have a matching module under
`deploy-permissions/`, using the same relative public or `internal/` path. The
companion must follow the repository lifecycle-policy interface and publish
`plan`, `create`, `update`, `destroy`, and `all` outputs.

Test a deploy-permissions module through an external consumer root under
`tests/contracts/<name>`, alongside the infrastructure module it permits. Do
not add the deploy-permissions module directory separately to the fast-test
loop.

Contract tests should verify:

- shared resource identifiers and lifecycle settings;
- successful composition through public inputs and outputs;
- the scope and resource targets of generated policies;
- the `plan`, `create`, `update`, `destroy`, and `all` lifecycle contract; and
- important validation failures at the consumer boundary.

Add the contract root to `MODULE_TEST_DIRECTORIES` and run it locally:

```console
tofu -chdir=tests/contracts/<name> init -backend=false
tofu -chdir=tests/contracts/<name> validate
tofu -chdir=tests/contracts/<name> test
```

A module without a deploy-permissions companion needs a contract root only when
it participates in a meaningful public interface with another module.

## Add compatibility coverage

Add a minimal external consumer root under
`tests/compatibility/fixtures/<name>/`. It must contain:

```text
tests/compatibility/fixtures/<name>/
├── main.tf
├── versions.tofu
└── minimum/
    └── providers.tf
```

`main.tf` should exercise the supported consumer graph without credentials.
`minimum/providers.tf` must list every provider in that graph, including
transitive provider dependencies, and pin each one to its exact tested minimum:

```hcl
terraform {
  required_providers {
    example = {
      source  = "organization/example"
      version = "= 1.2.3"
    }
  }
}
```

The compatibility runner autodiscovers fixture directories, so there is no
fixture list to update in CI. If an existing fixture already covers the new
module's provider graph, extend that fixture and its minimum profile instead of
adding redundant coverage.

Run both profiles locally:

```console
tests/compatibility/run.sh minimum
tests/compatibility/run.sh latest
```

The minimum profile verifies exact provider floors. The latest profile omits
the exact root constraints and uses `tofu init -upgrade` to select the newest
versions allowed by the modules. Both profiles initialize and validate
temporary consumer roots and discard their generated lock files.

CI runs both compatibility profiles with OpenTofu 1.10.0. The fast-test job
provides the latest-OpenTofu/latest-provider behavioral endpoint.

## Finish the repository integration

Before opening the pull request:

1. Update the root README module inventory and relevant
   `deploy-permissions/README.md` documentation.
2. Run `tofu fmt -check -recursive`.
3. Run the new module-local and applicable contract tests.
4. Run both compatibility profiles.
5. Confirm the minimum-profile summary reports every intended exact provider
   version.
6. Run the repository pre-commit checks, including `actionlint`.
7. Review any OpenTofu floor or provider upper-bound change as an explicit
   compatibility decision.
