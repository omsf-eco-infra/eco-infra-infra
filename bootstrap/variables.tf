variable "github_repository" {
  description = "GitHub repository that owns the tests workflow, in owner/repo form."
  type        = string
  default     = "omsf-eco-infra/eco-infra-infra"

  validation {
    condition     = can(regex("^[^/[:space:]]+/[^/[:space:]]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo form."
  }
}

variable "aws_region" {
  description = "AWS region used by the bootstrap stack and tests workflow."
  type        = string
  default     = "us-east-1"

  validation {
    condition     = length(trimspace(var.aws_region)) > 0
    error_message = "aws_region cannot be empty."
  }
}

variable "github_oidc_provider_arn" {
  description = "Optional ARN of the account-wide GitHub Actions OIDC provider. When omitted, the provider is discovered by URL."
  type        = string
  default     = null

  validation {
    condition = (
      var.github_oidc_provider_arn == null ||
      can(regex(":iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.github_oidc_provider_arn))
    )
    error_message = "github_oidc_provider_arn must identify token.actions.githubusercontent.com in an AWS account."
  }
}

variable "tags" {
  description = "Tags to apply to the GitHub Actions test role."
  type        = map(string)
  default     = {}
}
