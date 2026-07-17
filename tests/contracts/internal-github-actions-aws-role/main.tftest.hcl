mock_provider "aws" {
  alias = "mock"
}

mock_provider "github" {
  alias = "mock"
}

override_data {
  target = module.infrastructure.data.aws_iam_openid_connect_provider.github_by_arn
  values = {
    client_id_list = ["sts.amazonaws.com"]
  }
}

override_resource {
  target = module.infrastructure.aws_iam_role.github_actions
  values = {
    arn = "arn:aws:iam::123456789012:role/contract-test-role"
  }
}

override_data {
  target = module.deploy_permissions.data.aws_caller_identity.current
  values = {
    account_id = "123456789012"
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
    aws    = aws.mock
    github = github.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = module.infrastructure.role_name == var.role_name
    error_message = "The infrastructure module should manage the configured role."
  }

  assert {
    condition     = module.infrastructure.role_arn == "arn:aws:iam::123456789012:role/contract-test-role"
    error_message = "The infrastructure module should expose the managed role ARN."
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(output.permissions_all).Statement :
      statement.Resource == ["arn:aws:iam::123456789012:role/${var.role_name}"]
    ])
    error_message = "Every IAM operation should target the exact configured role ARN."
  }

  assert {
    condition = one([
      for statement in jsondecode(output.permissions_all).Statement : statement
      if statement.Sid == "GitHubActionsManagedPolicyAttach"
    ]).Condition.ArnEquals["iam:PolicyARN"] == [var.managed_policy_arns["readonly"]]
    error_message = "Managed policy attachment should be limited to the policy configured on the infrastructure module."
  }

  assert {
    condition = (
      contains(flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]), "iam:CreateRole") &&
      !contains(flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]), "iam:DeleteRole") &&
      contains(flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]), "iam:UpdateAssumeRolePolicy") &&
      !contains(flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]), "iam:CreateRole") &&
      contains(flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]), "iam:DeleteRole") &&
      !contains(flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]), "iam:CreateRole")
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

run "force_detach_contract" {
  command = plan

  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    force_detach_policies = true
  }

  assert {
    condition = (
      length([
        for statement in jsondecode(output.permissions_destroy).Statement : statement
        if statement.Sid == "GitHubActionsManagedPolicyForceDetach"
      ]) == 1 &&
      alltrue([
        for statement in jsondecode(output.permissions_destroy).Statement :
        !can(statement.Condition)
        if statement.Sid == "GitHubActionsManagedPolicyForceDetach"
      ])
    )
    error_message = "Force detach should emit exactly one unrestricted managed-policy detach statement."
  }
}

run "reject_invalid_shared_role_name" {
  command = plan

  providers = {
    aws    = aws.mock
    github = github.mock
  }

  variables {
    role_name = ""
  }

  expect_failures = [var.role_name]
}
