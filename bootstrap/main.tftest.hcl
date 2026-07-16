mock_provider "aws" {
  alias = "mock"
}

mock_provider "github" {
  alias = "mock"
}

override_data {
  target = module.test_role.data.aws_iam_openid_connect_provider.github_by_url
  values = {
    arn            = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    client_id_list = ["sts.amazonaws.com"]
  }
}

override_resource {
  target = module.test_role.aws_iam_role.github_actions
  values = {
    arn = "arn:aws:iam::123456789012:role/eco-infra-infra-tests"
  }
}

run "bootstrap_contract" {
  command = plan

  providers = {
    aws    = aws.mock
    github = github.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.github_oidc_provider_arn == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "Bootstrap should expose the discovered GitHub OIDC provider ARN."
  }

  assert {
    condition     = output.test_role_name == "eco-infra-infra-tests"
    error_message = "Bootstrap should create the expected test role."
  }

  assert {
    condition = tolist(module.test_role.oidc_subjects) == tolist([
      "repo:omsf-eco-infra/eco-infra-infra:pull_request:workflow_ref:omsf-eco-infra/eco-infra-infra/.github/workflows/tests.yaml@refs/pull/*/merge",
      "repo:omsf-eco-infra/eco-infra-infra:ref:refs/heads/main:workflow_ref:omsf-eco-infra/eco-infra-infra/.github/workflows/tests.yaml@refs/heads/main",
    ])
    error_message = "The test role should trust only main and pull-request runs of tests.yaml."
  }

  assert {
    condition     = module.repository_oidc.github_repository == var.github_repository
    error_message = "Repository OIDC customization should consume the test role contract."
  }

  assert {
    condition     = module.test_role.role_secret_name == "AWS_GHA_TEST_ROLE_ARN"
    error_message = "Bootstrap should publish the test role ARN under the expected secret name."
  }

  assert {
    condition     = github_actions_secret.aws_region.secret_name == "AWS_REGION"
    error_message = "Bootstrap should publish the AWS region under the expected secret name."
  }
}

run "custom_role_names" {
  command = plan

  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    role_name        = "custom-tests-role"
    role_secret_name = "CUSTOM_TEST_ROLE_ARN"
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.test_role_name == "custom-tests-role"
    error_message = "Bootstrap should pass a custom role name to the role module."
  }

  assert {
    condition     = module.test_role.role_secret_name == "CUSTOM_TEST_ROLE_ARN"
    error_message = "Bootstrap should pass a custom role secret name to the role module."
  }
}
