variable "role_name" {
  description = "Name of the IAM role that GitHub Actions workflows assume."
  type        = string

  validation {
    condition     = length(trimspace(var.role_name)) > 0 && length(var.role_name) <= 64
    error_message = "role_name must be non-empty and no longer than 64 characters."
  }
}

variable "role_description" {
  description = "Description for the GitHub Actions IAM role."
  type        = string
  default     = "Role assumed by explicitly trusted GitHub Actions workflows."
}

variable "max_session_duration" {
  description = "Maximum duration, in seconds, for sessions assumed through this role."
  type        = number
  default     = 3600

  validation {
    condition     = var.max_session_duration >= 3600 && var.max_session_duration <= 43200
    error_message = "max_session_duration must be between 3600 and 43200 seconds."
  }
}

variable "force_detach_policies" {
  description = "Detach policies attached outside this module before deleting the role."
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Optional ARN of the account's GitHub Actions OIDC identity provider. When omitted, the provider is discovered by URL."
  type        = string
  default     = null

  validation {
    condition = (
      var.github_oidc_provider_arn == null ||
      can(regex("^arn:[^:]+:iam::[0-9]{12}:oidc-provider/token\\.actions\\.githubusercontent\\.com$", var.github_oidc_provider_arn))
    )
    error_message = "github_oidc_provider_arn must identify token.actions.githubusercontent.com in an AWS account."
  }
}

variable "github_audience" {
  description = "Audience expected in GitHub's OIDC token."
  type        = string
  default     = "sts.amazonaws.com"

  validation {
    condition     = length(trimspace(var.github_audience)) > 0
    error_message = "github_audience cannot be empty."
  }
}

variable "github_repository" {
  description = "GitHub repository in owner/repo form."
  type        = string

  validation {
    condition     = can(regex("^[^/[:space:]]+/[^/[:space:]]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo form."
  }
}

variable "role_secret_name" {
  description = "Name of the GitHub Actions repository secret that stores the role ARN."
  type        = string

  validation {
    condition = (
      can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.role_secret_name)) &&
      !startswith(upper(var.role_secret_name), "GITHUB_")
    )
    error_message = "role_secret_name may contain only letters, numbers, and underscores; it cannot start with a number or GITHUB_."
  }
}

variable "trusted_workflows" {
  description = "Exact workflow and subject-context combinations allowed to assume the role, with optional workflow-ref overrides."
  type = list(object({
    workflow_filename = string
    workflow_ref      = optional(string)
    context = object({
      type  = string
      value = optional(string)
    })
  }))

  validation {
    condition     = length(var.trusted_workflows) > 0
    error_message = "trusted_workflows must contain at least one workflow entry."
  }

  validation {
    condition = alltrue([
      for workflow in var.trusted_workflows :
      can(regex("^[^/]+\\.ya?ml$", workflow.workflow_filename))
    ])
    error_message = "Each workflow_filename must be a .yml or .yaml filename directly under .github/workflows."
  }

  validation {
    condition = alltrue([
      for workflow in var.trusted_workflows :
      workflow.workflow_ref == null || can(regex("^refs/", workflow.workflow_ref))
    ])
    error_message = "Each explicit workflow_ref must start with refs/."
  }

  validation {
    condition = alltrue([
      for workflow in var.trusted_workflows :
      contains(["branch", "tag", "pull_request", "environment", "any"], workflow.context.type)
    ])
    error_message = "Each context type must be branch, tag, pull_request, environment, or any."
  }

  validation {
    condition = alltrue([
      for workflow in var.trusted_workflows :
      contains(["branch", "tag", "environment"], workflow.context.type)
      ? try(length(trimspace(workflow.context.value)) > 0, false)
      : workflow.context.value == null
    ])
    error_message = "Branch, tag, and environment contexts require a non-empty value; pull_request and any contexts must omit value."
  }

  validation {
    condition = alltrue([
      for workflow in var.trusted_workflows :
      workflow.context.type != "environment" || workflow.workflow_ref != null
    ])
    error_message = "Environment contexts require an explicit workflow_ref because the environment does not identify the workflow's source ref."
  }
}

variable "inline_policies" {
  description = "Map of stable policy identifiers to inline IAM policy JSON documents."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for name, policy in var.inline_policies :
      can(regex("^[0-9A-Za-z_+=,.@-]{1,128}$", name)) && can(keys(jsondecode(policy)))
    ])
    error_message = "inline_policies keys must be valid IAM inline policy names and values must be JSON objects."
  }
}

variable "managed_policy_arns" {
  description = "Map of stable attachment identifiers to managed IAM policy ARNs."
  type        = map(string)
  default     = {}

  validation {
    condition = alltrue([
      for name, arn in var.managed_policy_arns :
      length(trimspace(name)) > 0 && can(regex("^arn:[^:]+:iam::([0-9]{12}|aws):policy/.+", arn))
    ])
    error_message = "managed_policy_arns keys must be non-empty and values must be IAM managed policy ARNs."
  }
}

variable "tags" {
  description = "Tags to apply to the IAM role."
  type        = map(string)
  default     = {}
}
