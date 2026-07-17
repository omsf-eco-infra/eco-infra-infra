mock_provider "aws" {
  alias = "mock"
}

run "protected_github_oidc_configuration" {
  command = plan
  providers = {
    aws = aws.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 1
    error_message = "GitHub OIDC provider should be protected by default."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github_destroyable) == 0
    error_message = "The destroyable provider should not be created by default."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github[0].url == "https://token.actions.githubusercontent.com"
    error_message = "GitHub OIDC provider URL should match the GitHub Actions issuer."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github[0].client_id_list) == 1
    error_message = "GitHub OIDC provider should define exactly one audience."
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.github[0].client_id_list, "sts.amazonaws.com")
    error_message = "GitHub OIDC provider audience should be sts.amazonaws.com."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github[0].thumbprint_list) == 2
    error_message = "GitHub OIDC provider should define both compatibility thumbprints."
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.github[0].thumbprint_list, "6938fd4d98bab03faadb97b34396831e3780aea1")
    error_message = "GitHub OIDC provider should include the first compatibility thumbprint."
  }

  assert {
    condition     = contains(aws_iam_openid_connect_provider.github[0].thumbprint_list, "1c58a3a8518e8759bf075b76b750d4f2df264fcd")
    error_message = "GitHub OIDC provider should include the second compatibility thumbprint."
  }

  assert {
    condition     = output.github_oidc_provider_arn == aws_iam_openid_connect_provider.github[0].arn
    error_message = "Output ARN should match the managed GitHub OIDC provider ARN."
  }
}

run "destroyable_github_oidc_configuration" {
  command = plan

  providers = {
    aws = aws.mock
  }

  variables {
    prevent_destroy = false
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github) == 0
    error_message = "The protected provider should not be created when protection is disabled."
  }

  assert {
    condition     = length(aws_iam_openid_connect_provider.github_destroyable) == 1
    error_message = "A destroyable provider should be created when protection is disabled."
  }

  assert {
    condition     = aws_iam_openid_connect_provider.github_destroyable[0].url == "https://token.actions.githubusercontent.com"
    error_message = "Destroyable provider URL should match the GitHub Actions issuer."
  }

  assert {
    condition     = output.github_oidc_provider_arn == aws_iam_openid_connect_provider.github_destroyable[0].arn
    error_message = "Output ARN should match the destroyable GitHub OIDC provider ARN."
  }
}
