module "infrastructure" {
  source = "../../../modules/github-oidc"

  prevent_destroy = false
}

module "deploy_permissions" {
  source = "../../../deploy-permissions/github-oidc"
}

output "github_oidc_provider_arn" {
  value = module.infrastructure.github_oidc_provider_arn
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
