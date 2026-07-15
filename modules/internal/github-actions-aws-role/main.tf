locals {
  github_oidc_provider_url = "https://token.actions.githubusercontent.com"
  github_repository_name   = split("/", var.github_repository)[1]
  github_oidc_provider_arn = var.github_oidc_provider_arn == null ? data.aws_iam_openid_connect_provider.github_by_url[0].arn : data.aws_iam_openid_connect_provider.github_by_arn[0].arn
  subject_claim_keys       = ["repo", "context", "workflow_ref"]

  trusted_workflow_contexts = [
    for workflow in var.trusted_workflows :
    workflow.context.type == "branch" ? "ref:refs/heads/${replace(workflow.context.value, ":", "%3A")}" :
    workflow.context.type == "tag" ? "ref:refs/tags/${replace(workflow.context.value, ":", "%3A")}" :
    workflow.context.type == "environment" ? "environment:${replace(workflow.context.value, ":", "%3A")}" :
    workflow.context.type == "pull_request" ? "pull_request" : "*"
  ]

  trusted_workflow_refs = [
    for workflow in var.trusted_workflows :
    workflow.workflow_ref != null ? workflow.workflow_ref :
    workflow.context.type == "branch" ? "refs/heads/${workflow.context.value}" :
    workflow.context.type == "tag" ? "refs/tags/${workflow.context.value}" :
    workflow.context.type == "pull_request" ? "refs/pull/*/merge" : "refs/*"
  ]

  oidc_subjects = sort(distinct([
    for index, workflow in var.trusted_workflows :
    "repo:${var.github_repository}:${local.trusted_workflow_contexts[index]}:workflow_ref:${var.github_repository}/.github/workflows/${workflow.workflow_filename}@${local.trusted_workflow_refs[index]}"
  ]))

  assume_role_policy = {
    Version = "2012-10-17"
    Statement = [{
      Sid    = "GitHubActionsAssumeRole"
      Effect = "Allow"
      Principal = {
        Federated = local.github_oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = var.github_audience
        }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = local.oidc_subjects
        }
      }
    }]
  }
}

data "aws_iam_openid_connect_provider" "github_by_url" {
  count = var.github_oidc_provider_arn == null ? 1 : 0

  url = local.github_oidc_provider_url

  lifecycle {
    postcondition {
      condition     = contains(self.client_id_list, var.github_audience)
      error_message = "The GitHub OIDC provider must include github_audience in its client ID list."
    }
  }
}

data "aws_iam_openid_connect_provider" "github_by_arn" {
  count = var.github_oidc_provider_arn == null ? 0 : 1

  arn = var.github_oidc_provider_arn

  lifecycle {
    postcondition {
      condition     = contains(self.client_id_list, var.github_audience)
      error_message = "The GitHub OIDC provider must include github_audience in its client ID list."
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                  = var.role_name
  description           = var.role_description
  assume_role_policy    = jsonencode(local.assume_role_policy)
  max_session_duration  = var.max_session_duration
  force_detach_policies = var.force_detach_policies
  tags                  = var.tags
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies

  name   = each.key
  role   = aws_iam_role.github_actions.id
  policy = each.value
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = var.managed_policy_arns

  role       = aws_iam_role.github_actions.name
  policy_arn = each.value
}

resource "github_actions_secret" "role_arn" {
  repository  = local.github_repository_name
  secret_name = var.role_secret_name
  value       = aws_iam_role.github_actions.arn
}
