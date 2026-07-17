mock_provider "aws" {
  alias = "mock"
}

override_data {
  target = module.deploy_permissions.data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
  }
}

override_resource {
  target = module.infrastructure.aws_iam_openid_connect_provider.github_destroyable
  values = {
    arn = "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
  }
}

override_data {
  target = module.deploy_permissions.data.aws_partition.current
  values = {
    partition = "aws"
  }
}

run "resource_and_permissions_contract" {
  command = plan

  providers = {
    aws = aws.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = output.github_oidc_provider_arn == "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
    error_message = "The disposable infrastructure fixture should expose the managed GitHub Actions OIDC provider ARN."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(output.permissions_all).Statement :
      statement.Resource == (statement.Sid == "GitHubOidcDiscovery" ? ["*"] : ["arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"])
    ])
    error_message = "Provider operations should target the exact GitHub OIDC provider ARN; only discovery may target all resources."
  }

  assert {
    condition = (
      contains(flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]), "iam:CreateOpenIDConnectProvider") &&
      !contains(flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]), "iam:DeleteOpenIDConnectProvider") &&
      contains(flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]), "iam:UpdateOpenIDConnectProviderThumbprint") &&
      !contains(flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]), "iam:CreateOpenIDConnectProvider") &&
      contains(flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]), "iam:DeleteOpenIDConnectProvider") &&
      !contains(flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]), "iam:CreateOpenIDConnectProvider")
    )
    error_message = "Create, update, and destroy policies should contain only their lifecycle mutations."
  }

  assert {
    condition = (
      length(distinct([for statement in jsondecode(output.permissions_all).Statement : statement.Sid])) == length(jsondecode(output.permissions_all).Statement) &&
      length(setsubtract(
        toset(concat(
          flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]),
        )),
        toset(flatten([for statement in jsondecode(output.permissions_all).Statement : statement.Action])),
      )) == 0 &&
      length(setsubtract(
        toset(flatten([for statement in jsondecode(output.permissions_all).Statement : statement.Action])),
        toset(concat(
          flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]),
        )),
      )) == 0
    )
    error_message = "The all policy should be the deduplicated union of create, update, and destroy permissions."
  }
}
