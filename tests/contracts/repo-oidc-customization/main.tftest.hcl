mock_provider "aws" {
  alias = "mock"
}

mock_provider "github" {
  alias = "mock"
}

override_resource {
  target = module.role.aws_iam_role.github_actions
  values = {
    arn = "arn:aws:iam::123456789012:role/contract-test"
  }
}

override_data {
  target = module.role.data.aws_iam_openid_connect_provider.github_by_arn
  values = {
    client_id_list = ["sts.amazonaws.com"]
  }
}

run "role_to_repository_contract" {
  command = plan

  providers = {
    aws    = aws.mock
    github = github.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.role_repository == output.customization_repository
    error_message = "The role output should directly configure the same repository."
  }

  assert {
    condition     = tolist(output.include_claim_keys) == tolist(["repo", "context", "workflow_ref"])
    error_message = "The role and customization modules should agree on the claim contract."
  }
}
