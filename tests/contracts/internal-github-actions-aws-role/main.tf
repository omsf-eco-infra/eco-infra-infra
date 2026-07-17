variable "role_name" {
  type        = string
  description = "Role name shared by the infrastructure and deploy-permissions modules."
  default     = "contract-test-role"

  validation {
    condition     = length(trimspace(var.role_name)) > 0 && length(var.role_name) <= 64
    error_message = "role_name must be non-empty and no longer than 64 characters."
  }
}

variable "managed_policy_arns" {
  type        = map(string)
  description = "Managed policy ARNs shared by the infrastructure and deploy-permissions modules."
  default = {
    readonly = "arn:aws:iam::123456789012:policy/contract-readonly"
  }
}

variable "force_detach_policies" {
  type        = bool
  description = "Force-detach setting shared by the infrastructure and deploy-permissions modules."
  default     = false
}

module "infrastructure" {
  source = "../../../modules/internal/github-actions-aws-role"

  role_name                = var.role_name
  force_detach_policies    = var.force_detach_policies
  github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  github_repository        = "example-org/example-repo"
  role_secret_name         = "AWS_CONTRACT_ROLE_ARN"
  managed_policy_arns      = var.managed_policy_arns

  trusted_workflows = [{
    workflow_filename = "tests.yaml"
    context = {
      type  = "branch"
      value = "main"
    }
  }]
}

module "deploy_permissions" {
  source = "../../../deploy-permissions/internal/github-actions-aws-role"

  role_name             = var.role_name
  managed_policy_arns   = var.managed_policy_arns
  force_detach_policies = var.force_detach_policies
}

output "permissions_plan" {
  value = module.deploy_permissions.plan
}

output "permissions_create" {
  value = module.deploy_permissions.create
}

output "permissions_update" {
  value = module.deploy_permissions.update
}

output "permissions_destroy" {
  value = module.deploy_permissions.destroy
}

output "permissions_all" {
  value = module.deploy_permissions.all
}
