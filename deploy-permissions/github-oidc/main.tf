data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  provider_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"

  statements = {
    discovery = {
      Sid    = "GitHubOidcDiscovery"
      Effect = "Allow"
      Action = [
        "iam:ListOpenIDConnectProviders",
      ]
      Resource = ["*"]
    }

    provider_read = {
      Sid    = "GitHubOidcRead"
      Effect = "Allow"
      Action = [
        "iam:GetOpenIDConnectProvider",
      ]
      Resource = [local.provider_arn]
    }

    provider_create = {
      Sid    = "GitHubOidcCreate"
      Effect = "Allow"
      Action = [
        "iam:CreateOpenIDConnectProvider",
      ]
      Resource = [local.provider_arn]
    }

    provider_update = {
      Sid    = "GitHubOidcUpdate"
      Effect = "Allow"
      Action = [
        "iam:AddClientIDToOpenIDConnectProvider",
        "iam:RemoveClientIDFromOpenIDConnectProvider",
        "iam:UpdateOpenIDConnectProviderThumbprint",
      ]
      Resource = [local.provider_arn]
    }

    provider_destroy = {
      Sid    = "GitHubOidcDestroy"
      Effect = "Allow"
      Action = [
        "iam:DeleteOpenIDConnectProvider",
      ]
      Resource = [local.provider_arn]
    }
  }

  policies = {
    plan = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.provider_read,
      ]
    }

    create = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.provider_read,
        local.statements.provider_create,
      ]
    }

    update = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.provider_read,
        local.statements.provider_update,
      ]
    }

    destroy = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.provider_read,
        local.statements.provider_destroy,
      ]
    }

    all = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.provider_read,
        local.statements.provider_create,
        local.statements.provider_update,
        local.statements.provider_destroy,
      ]
    }
  }
}
