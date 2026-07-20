variable "role_name" {
  description = "Name of the IAM role managed by the paired github-actions-aws-role module."
  type        = string

  validation {
    condition     = length(trimspace(var.role_name)) > 0 && length(var.role_name) <= 64
    error_message = "role_name must be non-empty and no longer than 64 characters."
  }
}

variable "managed_policy_arns" {
  description = "Managed policy ARNs attached by the paired role module."
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

variable "force_detach_policies" {
  description = "Allow detaching any managed policy from the exact role during destruction."
  type        = bool
  default     = false
}
