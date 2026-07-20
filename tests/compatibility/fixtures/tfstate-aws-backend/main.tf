module "infrastructure" {
  source = "../../../../modules/tfstate-aws-backend"

  bucket_name = "compatibility-test-tfstate"
}

module "deploy_permissions" {
  source = "../../../../deploy-permissions/tfstate-aws-backend"

  bucket_name = "compatibility-test-tfstate"
}
