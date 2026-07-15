locals {
  github_repository_name = split("/", var.github_repository)[1]
}

module "test_role" {
  source = "../modules/internal/github-actions-aws-role"

  role_name                = var.role_name
  role_secret_name         = var.role_secret_name
  role_description         = "Role assumed by the eco-infra-infra tests workflow."
  github_oidc_provider_arn = var.github_oidc_provider_arn
  github_repository        = var.github_repository

  trusted_workflows = [
    {
      workflow_filename = "tests.yaml"
      context = {
        type  = "branch"
        value = "main"
      }
    },
    {
      workflow_filename = "tests.yaml"
      context = {
        type = "pull_request"
      }
    },
  ]

  tags = var.tags
}

module "repository_oidc" {
  source = "../modules/internal/repo-oidc-customization"

  role_configurations = [
    module.test_role.repository_oidc_configuration,
  ]
}

resource "github_actions_secret" "aws_region" {
  repository  = local.github_repository_name
  secret_name = "AWS_REGION"
  value       = var.aws_region

  depends_on = [module.repository_oidc]
}
