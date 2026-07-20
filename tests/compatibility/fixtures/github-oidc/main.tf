module "infrastructure" {
  source = "../../../../modules/github-oidc"

  prevent_destroy = false
}

module "deploy_permissions" {
  source = "../../../../deploy-permissions/github-oidc"
}
