# github-oidc

Creates the AWS IAM OpenID Connect provider used by GitHub Actions for OIDC
federation into an AWS account.

This module is intended as a small bootstrap primitive. Most accounts need
exactly one GitHub OIDC provider, which can then be referenced by one or more
IAM roles with repository- or workflow-specific trust policies.

## Requirements

- Terraform or OpenTofu
- AWS provider `~> 4.0`

## Inputs

This module has no inputs.

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

## Security Notes

- This module creates only the identity provider.
- Downstream IAM roles should still restrict GitHub OIDC claims such as
  `token.actions.githubusercontent.com:sub` so only intended repositories,
  branches, environments, or workflows can assume the role.
- The provider uses GitHub's standard issuer URL and `sts.amazonaws.com`
  audience for `aws-actions/configure-aws-credentials`.
