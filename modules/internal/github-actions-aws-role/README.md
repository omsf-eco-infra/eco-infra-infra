# github-actions-aws-role

Creates an AWS IAM role that only explicitly configured GitHub Actions caller
workflows can assume. The module also attaches caller-supplied inline and
managed IAM policies, discovers the account-wide GitHub OIDC provider when its
ARN is omitted, and publishes the role ARN as a repository Actions secret.

This is an internal building block. It expects the repository to use the OIDC
subject template managed by
[`../repo-oidc-customization`](../repo-oidc-customization), which emits subjects
containing `repo`, `context`, and `workflow_ref`.

## Usage

```hcl
module "deploy_role" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//modules/internal/github-actions-aws-role"

  role_name         = "example-deployer"
  role_secret_name  = "AWS_DEPLOY_ROLE_ARN"
  github_repository = "example-org/example-repo"

  trusted_workflows = [
    {
      workflow_filename = "deploy.yml"
      workflow_ref      = "refs/heads/main"
      context = {
        type  = "branch"
        value = "main"
      }
    },
    {
      workflow_filename = "deploy.yml"
      workflow_ref      = "refs/pull/*"
      context = {
        type = "pull_request"
      }
    },
  ]

  inline_policies = {
    deploy = data.aws_iam_policy_document.deploy.json
  }

  managed_policy_arns = {
    shared-read = aws_iam_policy.shared_read.arn
  }

  tags = {
    managed_by = "tofu"
  }
}

module "repository_oidc" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//modules/internal/repo-oidc-customization"

  role_configurations = [
    module.deploy_role.repository_oidc_configuration,
  ]
}
```

The AWS provider must select the account containing the role and GitHub OIDC
provider. The GitHub provider passed to this module and `repository_oidc` must
be configured for `example-org`. Set `github_oidc_provider_arn` to select a
specific provider; otherwise the module looks up
`https://token.actions.githubusercontent.com` in the selected AWS account.

The role secret is created after the IAM role, but it can be created in
parallel with the separate repository OIDC customization. A workflow started
during that apply can fail until customization is complete.

## Workflow trust entries

Each entry represents one exact workflow/ref/context combination. Supported
contexts are:

| Type | Value | Subject context | Default workflow ref |
| --- | --- | --- | --- |
| `branch` | Required; patterns allowed | `ref:refs/heads/<value>` | `refs/heads/<value>` |
| `tag` | Required; patterns allowed | `ref:refs/tags/<value>` | `refs/tags/<value>` |
| `pull_request` | Omit | `pull_request` | `refs/pull/*/merge` |
| `environment` | Required; patterns allowed | `environment:<value>` | None; explicit ref required |
| `any` | Omit | `*` | `refs/*` |

`workflow_ref` is optional except for environment contexts. An explicitly
provided value always overrides the context-derived default. The pull-request
default covers ordinary open `pull_request` runs; merged/closed PR jobs and
`pull_request_target` workflows should provide the ref pattern they actually
use.

Colons in context values are encoded as `%3A`. Every resulting subject also
contains the repository and caller workflow identity:

```text
repo:owner/repo:<context>:workflow_ref:owner/repo/.github/workflows/file.yml@refs/...
```

`any` retains workflow-level restriction while accepting every GitHub subject
context. Because subjects use IAM `StringLike`, wildcards in context values and
workflow refs are meaningful and should be reviewed carefully.

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `role_name` | `string` | required | IAM role name |
| `role_secret_name` | `string` | required | Repository Actions secret that receives the role ARN |
| `github_oidc_provider_arn` | `string` | `null` | Optional account GitHub OIDC provider ARN; discovered by URL when omitted |
| `github_repository` | `string` | required | Repository in `owner/repo` form |
| `trusted_workflows` | `list(object)` | required | Exact allowed workflow combinations; workflow refs may use context defaults |
| `role_description` | `string` | workflow-role description | IAM role description |
| `max_session_duration` | `number` | `3600` | Session limit from 3600 through 43200 seconds |
| `force_detach_policies` | `bool` | `false` | Detach out-of-band policies during role deletion |
| `github_audience` | `string` | `sts.amazonaws.com` | Required OIDC audience |
| `inline_policies` | `map(string)` | `{}` | Stable policy names mapped to JSON documents |
| `managed_policy_arns` | `map(string)` | `{}` | Stable attachment keys mapped to policy ARNs |
| `tags` | `map(string)` | `{}` | IAM role tags |

## Outputs

- `role_name` and `role_arn`
- `github_oidc_provider_arn` and `role_secret_name`
- `assume_role_policy_json`
- `oidc_subjects`
- `repository_oidc_configuration`: non-sensitive readiness contract for the
  repository customization module

## Compatibility and migration

- The module targets caller workflows with `workflow_ref`. It does not enforce
  reusable workflows with `job_workflow_ref`.
- It intentionally has no raw or default-subject mode.
- V1 constructs GitHub's name-based subjects. GitHub repositories using the
  immutable owner/repository-ID subject format are not supported until the
  GitHub Terraform provider can manage `use_immutable_subject` end to end.
  GitHub begins using immutable subjects by default for newly created
  repositories on July 15, 2026, so check the repository setting before use.
- Changing a repository's OIDC template changes tokens for every role used by
  that repository. Migrate all roles before applying the repository module.
  When replacing live roles, use parallel roles and switch workflow secrets
  only after the new template is active.
- For roles in another Terraform state or AWS account, apply every role state
  before the state containing `repo-oidc-customization`.

### Existing implementation mappings

- **ami-builder:** use `any` context with `refs/*` where all events are needed,
  pass Packer/cleanup/test permissions as inline policies, and aggregate every
  role contract into one repository customization. This replaces its custom
  `job_workflow_ref` subject with caller `workflow_ref`.
- **cloud-cron:** continue generating its service-specific managed permission
  sets outside this module and pass their ARNs through `managed_policy_arns`.
  Express each existing branch/environment subject and workflow pairing as an
  exact trust entry instead of using an independent `job_workflow_ref` IAM
  condition.
- **website-backend:** continue using `modules/github-oidc` for the account
  provider, pass the sandbox document through `inline_policies`, and use
  separate main-branch and pull-request trust entries for `terraform.yaml`.
  Pass the existing role-secret name to this module.
