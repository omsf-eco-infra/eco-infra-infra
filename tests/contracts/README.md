# Contract tests

The tests in this directory exercise modules as an external consumer would use
them. Each contract root composes an infrastructure module with its matching
module under `deploy-permissions/` and passes the same resource identifiers and
relevant lifecycle settings to both.

This is also the primary location for testing deploy-permissions contracts.
Deploy-permissions modules do not have committed module-local `.tftest.hcl`
files. Their generated IAM policies are tested here alongside the
infrastructure modules those policies are intended to deploy.

## Contract tests versus module tests

Module-local tests under `modules/` can inspect a module's internal resources.
They verify details such as encryption, lifecycle settings, trust policies,
resource selection, outputs, and input validation.

Contract tests use child modules through their public interfaces. They verify
that independently maintained modules can be composed correctly, without
depending on the child modules' internal resource addresses.

| Module-local tests | Contract tests |
| --- | --- |
| Exercise one module | Compose infrastructure and deploy-permissions modules |
| Inspect internal resources | Use public inputs and outputs |
| Verify resource configuration | Verify cross-module interface compatibility |
| Catch implementation regressions | Catch mismatched identifiers, settings, and policy scope |

The two levels are complementary. For example, the
`tfstate-aws-backend` module test verifies bucket versioning and encryption,
while its contract test verifies that the companion policy targets that same
bucket and provides the expected lifecycle permissions.

## Deploy-permissions contract

Each applicable contract root should verify that:

- the infrastructure and deploy-permissions modules accept the same resource
  identifiers and shared lifecycle settings;
- the composed configuration initializes and plans successfully;
- generated statements target the exact resource ARN, except where an AWS API
  requires a discovery action on all resources;
- `plan`, `create`, `update`, and `destroy` contain the appropriate lifecycle
  operations without unrelated mutations;
- `all` is the deduplicated union of `create`, `update`, and `destroy`; and
- important shared input failures remain actionable at the consumer boundary.

Live lifecycle tests will later exercise these policies against AWS. The
contract tests remain the fast, credential-free check for policy generation
and module composition.

Modules that configure only a non-AWS provider do not need an AWS
deploy-permissions companion. Their cross-module contracts may still be tested
elsewhere when they publish values consumed by another module.

## Running the tests

Run a contract root in the same way as any other OpenTofu test root:

```console
tofu -chdir=tests/contracts/github-oidc init -backend=false
tofu -chdir=tests/contracts/github-oidc test
```

The fast-test workflow runs every committed contract root. Provider lock files
created while running these reusable test roots locally are ignored and should
not be committed.
