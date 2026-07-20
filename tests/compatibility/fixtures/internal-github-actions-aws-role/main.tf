module "infrastructure" {
  source = "../../../../modules/internal/github-actions-aws-role"

  role_name                = "compatibility-test-role"
  role_secret_name         = "AWS_COMPATIBILITY_TEST_ROLE_ARN"
  github_oidc_provider_arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  github_repository        = "example-org/example-repo"

  trusted_workflows = [{
    workflow_filename = "tests.yaml"
    context = {
      type  = "branch"
      value = "main"
    }
  }]
}

module "deploy_permissions" {
  source = "../../../../deploy-permissions/internal/github-actions-aws-role"

  role_name = "compatibility-test-role"
}
