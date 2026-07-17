locals {
  github_oidc_url        = "https://token.actions.githubusercontent.com"
  github_oidc_client_ids = ["sts.amazonaws.com"]

  # TODO: Remove thumbprint_list when this module can require a newer AWS
  # provider version that supports omitting it for GitHub OIDC.
  github_oidc_thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.prevent_destroy ? 1 : 0

  url             = local.github_oidc_url
  client_id_list  = local.github_oidc_client_ids
  thumbprint_list = local.github_oidc_thumbprint_list

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_iam_openid_connect_provider" "github_destroyable" {
  count = var.prevent_destroy ? 0 : 1

  url             = local.github_oidc_url
  client_id_list  = local.github_oidc_client_ids
  thumbprint_list = local.github_oidc_thumbprint_list
}

moved {
  from = aws_iam_openid_connect_provider.github
  to   = aws_iam_openid_connect_provider.github[0]
}
