# Test infrastructure bootstrap

This root module creates the permissionless AWS IAM role assumed by the
repository's tests workflow, configures the repository's GitHub OIDC subject
template, and publishes the role ARN and AWS region as GitHub Actions secrets.
The role module owns OIDC provider discovery and role-secret publication;
bootstrap supplies repository-specific defaults and continues to own the
region secret.

This is intended to provide the infrastructure that allows us to run live tests of the repository's reusable modules. It is not intended to be reused by end users (unless you are setting it up for a fork of this repo).

## Account architecture

The `eco-infra-infra-tests` role belongs in the root AWS account. GitHub
Actions assumes this role directly through OIDC, making it the workflow's
initial AWS identity and the trust anchor for the test infrastructure.

For now, this bootstrap creates only that root-account OIDC role. The role is
intentionally permissionless, so the current workflow can verify OIDC role
assumption but cannot deploy AWS resources.

Future live tests will use a two-account design:

1. The workflow will assume `eco-infra-infra-tests` through GitHub OIDC in the
   root account.
2. OpenTofu's S3 backend will use that root-account identity to read, write,
   and lock test state in a root-account state bucket.
3. The AWS provider will use the root role to assume the persistent deployment
   role for the fixture type being tested in the sandbox account.
4. Each fixture deployment role will receive only the generated permissions
   needed to create and destroy that fixture type in the sandbox account.

The S3 backend and AWS provider authenticate independently. Live test roots
will therefore configure the backend to use the workflow's ambient root-role
credentials while configuring the AWS provider with an `assume_role` block for
the appropriate fixture deployment role. Fixture roles will not need access to
the root state bucket.

When live tests are introduced, this bootstrap is expected to grow to:

- create one persistent sandbox deployment role for each live fixture type;
- allow only `eco-infra-infra-tests` to assume those roles;
- grant the root role access to the test-state bucket and permission to assume
  the exact, enumerated fixture-role ARNs; and
- attach the matching `all` policy from `deploy-permissions/` to each fixture
  role.

Workflow runs will reuse the persistent role for their fixture type while
keeping resource names and state isolated by pull request and run. Workflows
will not create or destroy deployment roles dynamically; the root role will
therefore need permission to assume the enumerated roles, but not permission to
manage IAM roles in the sandbox account.

The existing `deploy-permissions/tfstate-aws-backend` module manages permissions
for deploying the bucket itself; it does not provide the runtime S3 object
permissions required to use that bucket as an OpenTofu backend.

The account-wide GitHub Actions OIDC provider must already exist. Set
`github_oidc_provider_arn` to use a specific provider, or omit it to look up the
provider at `https://token.actions.githubusercontent.com`. If lookup fails,
confirm that the provider exists in the AWS account selected by your current
credentials.

## Bootstrap locally

Before applying, confirm that:

- your AWS credentials select the root account where the test role should live;
- an S3 bucket for the bootstrap state already exists in that account;
- the account-wide GitHub Actions OIDC provider already exists;
- the repository does not have another OIDC role that would be broken by
  changing its repository-wide subject template; and
- `GITHUB_TOKEN` contains a GitHub token that can manage Actions secrets and
  the repository OIDC customization.

Check the selected AWS account before initializing:

```console
aws sts get-caller-identity
export GITHUB_TOKEN=<github-token>
```

The S3 backend has defaults in `bootstrap/providers.tf`, but you can override the
bucket/key/region at initialization time:

```console
tofu -chdir=bootstrap init \
  -backend-config="bucket=<state-bucket>" \
  -backend-config="key=eco-infra-infra-tests/bootstrap/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="use_lockfile=true"
tofu -chdir=bootstrap plan -out=/tmp/eco-infra-infra-bootstrap.tfplan
tofu -chdir=bootstrap apply /tmp/eco-infra-infra-bootstrap.tfplan
```

Override `github_repository` during the plan if applying this bootstrap to a
repository other than `omsf-eco-infra/eco-infra-infra`. Override `role_name` or
`role_secret_name` to replace the defaults `eco-infra-infra-tests` and
`AWS_GHA_TEST_ROLE_ARN`.

The AWS credentials used for the apply must be able to read the account OIDC
provider and manage the test IAM role. Configure the GitHub provider with a
token that can manage Actions secrets and the repository OIDC customization,
for example through the `GITHUB_TOKEN` environment variable.

The test role intentionally has no workload permissions. Add a persistent
fixture role with permissions from the matching module under
`deploy-permissions/` only when the live suite begins creating and destroying
that fixture type.

## Enable the tests workflow

The initial workflow deliberately runs only these complete, mocked contract
test suites:

- `bootstrap`;
- `modules/internal/github-actions-aws-role`;
- `modules/internal/repo-oidc-customization`.

These test groups validate the bootstrap, each internal module, and the
contract between the two internal modules. None of these contract tests call
AWS or GitHub. After they pass, the `aws-oidc-smoke` job uses the secrets
created by this bootstrap and calls `aws sts get-caller-identity` with the real
OIDC role.

Before pushing the workflow, add the following source and test files to the
commit:

- `.github/workflows/tests.yaml`;
- all source files under `bootstrap/`, including `main.tftest.hcl` and the
  bootstrap dependency lock file;
- `modules/internal/github-actions-aws-role/main.tftest.hcl`;
- the two `.tftest.hcl` files and `tests/integration/` under
  `modules/internal/repo-oidc-customization`.

Do not add `.terraform/`, `.tfdata-test/`, editor swap files, state files, or
generated provider binaries. Lock files created while testing reusable modules
are not required; the bootstrap lock file is retained because `bootstrap/` is a
root configuration.

Pushes run the mocked contract tests. The live OIDC smoke job runs on pushes to
`main`, manual runs on `main`, and same-repository pull requests. Pull requests
from forks skip the complete job chain.
