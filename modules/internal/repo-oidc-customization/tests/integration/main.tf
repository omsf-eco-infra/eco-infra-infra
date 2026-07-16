module "role" {
  source = "../../../github-actions-aws-role"

  role_name                = "contract-test"
  role_secret_name         = "AWS_CONTRACT_TEST_ROLE_ARN"
  github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  github_repository        = "example-org/example-repo"
  trusted_workflows = [{
    workflow_filename = "deploy.yml"
    context = {
      type  = "branch"
      value = "main"
    }
  }]
}

module "repository_customization" {
  source = "../.."

  role_configurations = [module.role.repository_oidc_configuration]
}

output "role_repository" {
  value = module.role.repository_oidc_configuration.github_repository
}

output "customization_repository" {
  value = module.repository_customization.github_repository
}

output "include_claim_keys" {
  value = module.repository_customization.include_claim_keys
}
