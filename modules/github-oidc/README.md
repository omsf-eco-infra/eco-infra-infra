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

The module currently configures these GitHub thumbprints:

- `6938fd4d98bab03faadb97b34396831e3780aea1`
- `1c58a3a8518e8759bf075b76b750d4f2df264fcd`

## Security Notes

- This module creates only the identity provider.
- Downstream IAM roles should still restrict GitHub OIDC claims such as
  `token.actions.githubusercontent.com:sub` so only intended repositories,
  branches, environments, or workflows can assume the role.
- The provider uses GitHub's standard issuer URL and `sts.amazonaws.com`
  audience for `aws-actions/configure-aws-credentials`.
- The configured thumbprints are a compatibility requirement for the provider
  version this module currently supports, not the preferred long-term AWS
  configuration model.
