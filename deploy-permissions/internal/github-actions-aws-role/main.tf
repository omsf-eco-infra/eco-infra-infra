data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  role_arn            = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.role_name}"
  managed_policy_arns = sort(values(var.managed_policy_arns))

  statements = {
    role_read = {
      Sid    = "GitHubActionsRoleRead"
      Effect = "Allow"
      Action = [
        "iam:GetRole",
        "iam:GetRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:ListRoleTags",
      ]
      Resource = [local.role_arn]
    }

    role_create = {
      Sid    = "GitHubActionsRoleCreate"
      Effect = "Allow"
      Action = [
        "iam:CreateRole",
        "iam:TagRole",
      ]
      Resource = [local.role_arn]
    }

    role_update = {
      Sid    = "GitHubActionsRoleUpdate"
      Effect = "Allow"
      Action = [
        "iam:TagRole",
        "iam:UntagRole",
        "iam:UpdateAssumeRolePolicy",
        "iam:UpdateRole",
        "iam:UpdateRoleDescription",
      ]
      Resource = [local.role_arn]
    }

    inline_policy_upsert = {
      Sid      = "GitHubActionsInlinePolicyUpsert"
      Effect   = "Allow"
      Action   = ["iam:PutRolePolicy"]
      Resource = [local.role_arn]
    }

    inline_policy_delete = {
      Sid      = "GitHubActionsInlinePolicyDelete"
      Effect   = "Allow"
      Action   = ["iam:DeleteRolePolicy"]
      Resource = [local.role_arn]
    }

    managed_policy_attach = {
      Sid      = "GitHubActionsManagedPolicyAttach"
      Effect   = "Allow"
      Action   = ["iam:AttachRolePolicy"]
      Resource = [local.role_arn]
      Condition = {
        ArnEquals = {
          "iam:PolicyARN" = local.managed_policy_arns
        }
      }
    }

    managed_policy_detach_scoped = {
      Sid      = "GitHubActionsManagedPolicyDetach"
      Effect   = "Allow"
      Action   = ["iam:DetachRolePolicy"]
      Resource = [local.role_arn]
      Condition = {
        ArnEquals = {
          "iam:PolicyARN" = local.managed_policy_arns
        }
      }
    }

    managed_policy_detach_all = {
      Sid      = "GitHubActionsManagedPolicyForceDetach"
      Effect   = "Allow"
      Action   = ["iam:DetachRolePolicy"]
      Resource = [local.role_arn]
    }

    role_destroy = {
      Sid      = "GitHubActionsRoleDestroy"
      Effect   = "Allow"
      Action   = ["iam:DeleteRole"]
      Resource = [local.role_arn]
    }
  }

  managed_policy_attach_statements = length(local.managed_policy_arns) > 0 ? [local.statements.managed_policy_attach] : []
  managed_policy_detach_statements = concat(
    var.force_detach_policies ? [local.statements.managed_policy_detach_all] : [],
    !var.force_detach_policies && length(local.managed_policy_arns) > 0 ? [local.statements.managed_policy_detach_scoped] : [],
  )

  policy_statements = {
    plan = [
      local.statements.role_read,
    ]

    create = concat(
      [
        local.statements.role_read,
        local.statements.role_create,
        local.statements.inline_policy_upsert,
      ],
      local.managed_policy_attach_statements,
    )

    update = concat(
      [
        local.statements.role_read,
        local.statements.role_update,
        local.statements.inline_policy_upsert,
        local.statements.inline_policy_delete,
      ],
      local.managed_policy_attach_statements,
      local.managed_policy_detach_statements,
    )

    destroy = concat(
      [
        local.statements.role_read,
        local.statements.inline_policy_delete,
      ],
      local.managed_policy_detach_statements,
      [local.statements.role_destroy],
    )

    all = concat(
      [
        local.statements.role_read,
        local.statements.role_create,
        local.statements.role_update,
        local.statements.inline_policy_upsert,
        local.statements.inline_policy_delete,
      ],
      local.managed_policy_attach_statements,
      local.managed_policy_detach_statements,
      [local.statements.role_destroy],
    )
  }

  policies = {
    for lifecycle, statements in local.policy_statements : lifecycle => {
      Version   = "2012-10-17"
      Statement = statements
    }
  }
}
