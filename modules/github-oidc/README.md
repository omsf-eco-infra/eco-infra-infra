# github-oidc

Creates the AWS IAM OpenID Connect provider used by GitHub Actions for OIDC
federation into an AWS account.

This module is intended as a small bootstrap primitive. Most accounts need
exactly one GitHub OIDC provider, which can then be referenced by one or more
IAM roles with repository- or workflow-specific trust policies.

Because this module currently keeps the AWS provider pinned to `~> 4.0`, it
includes GitHub OIDC thumbprints explicitly for provider compatibility. Newer
AWS provider versions allow this argument to be omitted for GitHub's issuer,
which is AWS's preferred modern behavior.

## Requirements

- Terraform or OpenTofu
- AWS provider `~> 4.0`

## Inputs

| Name | Type | Default | Description |
| --- | --- | --- | --- |
| `prevent_destroy` | `bool` | `true` | Protect the provider from deletion; set to `false` only for disposable fixtures |

## Outputs

| Name | Type | Description |
| --- | --- | --- |
| `github_oidc_provider_arn` | `string` | ARN of the GitHub Actions OIDC provider |

## Usage

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # Configure the AWS provider for the target account.
}

module "github_oidc" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//modules/github-oidc"
}
```

After creation, pass `module.github_oidc.github_oidc_provider_arn` into
downstream modules or IAM role definitions that trust GitHub Actions.

The provider is protected from destruction by default. Disposable sandbox
fixtures can opt into normal destruction when they are first created:

```hcl
module "github_oidc" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//modules/github-oidc"

  prevent_destroy = false
}
```

OpenTofu requires `lifecycle.prevent_destroy` to be a literal value. The module
therefore uses separate protected and destroyable resource addresses. Treat
`prevent_destroy` as immutable after creation. Changing it for an existing
provider requires moving the resource in state before planning; otherwise AWS
will reject an attempt to create a second provider with the same issuer URL.

The module currently configures these GitHub thumbprints:

- `6938fd4d98bab03faadb97b34396831e3780aea1`
- `1c58a3a8518e8759bf075b76b750d4f2df264fcd`

## Security Notes

- This module creates only the identity provider.
- Destruction protection defaults to enabled. Disable it only in a dedicated
  sandbox where automated cleanup is required.
- Downstream IAM roles should still restrict GitHub OIDC claims such as
  `token.actions.githubusercontent.com:sub` so only intended repositories,
  branches, environments, or workflows can assume the role.
- The provider uses GitHub's standard issuer URL and `sts.amazonaws.com`
  audience for `aws-actions/configure-aws-credentials`.
- The configured thumbprints are a compatibility requirement for the provider
  version this module currently supports, not the preferred long-term AWS
  configuration model.
