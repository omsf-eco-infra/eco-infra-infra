variable "role_configurations" {
  description = "Repository OIDC contracts output by every github-actions-aws-role module for this repository."
  type = list(object({
    github_repository  = string
    include_claim_keys = list(string)
    ready_role_arn     = string
  }))

  validation {
    condition     = length(var.role_configurations) > 0
    error_message = "role_configurations must contain at least one role contract."
  }

  validation {
    condition = length(var.role_configurations) == 0 || (
      length(distinct([for configuration in var.role_configurations : configuration.github_repository])) == 1 &&
      alltrue([
        for configuration in var.role_configurations :
        can(regex("^[^/[:space:]]+/[^/[:space:]]+$", configuration.github_repository))
      ])
    )
    error_message = "All role configurations must use the same valid owner/repo repository."
  }

  validation {
    condition = length(var.role_configurations) == 0 || alltrue([
      for configuration in var.role_configurations :
      length(configuration.include_claim_keys) > 0 &&
      alltrue([for claim_key in configuration.include_claim_keys : can(regex("^[0-9A-Za-z_]+$", claim_key))])
    ])
    error_message = "Every role configuration must contain at least one valid OIDC claim key."
  }

  validation {
    condition = length(var.role_configurations) == 0 || alltrue([
      for configuration in var.role_configurations :
      jsonencode(configuration.include_claim_keys) == jsonencode(var.role_configurations[0].include_claim_keys)
    ])
    error_message = "All role configurations must use the same ordered OIDC claim keys."
  }

  validation {
    condition = alltrue([
      for configuration in var.role_configurations :
      can(regex("^arn:[^:]+:iam::[0-9]{12}:role/.+", configuration.ready_role_arn))
    ])
    error_message = "Every role configuration must contain a valid ready_role_arn."
  }
}
