variable "bucket_name" {
  type        = string
  description = "Name shared by the infrastructure and deploy-permissions modules."
  default     = "contract-test-tfstate"
}

module "infrastructure" {
  source = "../../../modules/tfstate-aws-backend"

  bucket_name = var.bucket_name
}

module "deploy_permissions" {
  source = "../../../deploy-permissions/tfstate-aws-backend"

  bucket_name = var.bucket_name
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
