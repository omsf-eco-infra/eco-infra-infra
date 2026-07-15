locals {
  github_oidc_provider_url = "https://token.actions.githubusercontent.com"
  github_repository_name   = split("/", var.github_repository)[1]
  test_role_name           = "eco-infra-infra-tests"
}

data "aws_iam_openid_connect_provider" "github" {
  arn = var.github_oidc_provider_arn
  url = var.github_oidc_provider_arn == null ? local.github_oidc_provider_url : null

  lifecycle {
    postcondition {
      condition     = contains(self.client_id_list, "sts.amazonaws.com")
      error_message = "The GitHub OIDC provider must include sts.amazonaws.com in its client ID list."
    }
  }
}

module "test_role" {
  source = "../modules/internal/github-actions-aws-role"

  role_name                = local.test_role_name
  role_description         = "Role assumed by the eco-infra-infra tests workflow."
  github_oidc_provider_arn = data.aws_iam_openid_connect_provider.github.arn
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

resource "github_actions_secret" "test_role_arn" {
  repository  = local.github_repository_name
  secret_name = "AWS_GHA_TEST_ROLE_ARN"
  value       = module.test_role.role_arn

  depends_on = [module.repository_oidc]
}

resource "github_actions_secret" "aws_region" {
  repository  = local.github_repository_name
  secret_name = "AWS_REGION"
  value       = var.aws_region

  depends_on = [module.repository_oidc]
}
