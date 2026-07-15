output "role_name" {
  description = "Name of the GitHub Actions IAM role."
  value       = aws_iam_role.github_actions.name
}

output "role_arn" {
  description = "ARN of the GitHub Actions IAM role."
  value       = aws_iam_role.github_actions.arn
}

output "assume_role_policy_json" {
  description = "Rendered IAM trust policy JSON."
  value       = jsonencode(local.assume_role_policy)
}

output "oidc_subjects" {
  description = "Sorted customized OIDC subjects allowed to assume the role."
  value       = local.oidc_subjects
}

output "repository_oidc_configuration" {
  description = "Repository OIDC contract consumed by the repo-oidc-customization module."
  value = {
    github_repository  = var.github_repository
    include_claim_keys = local.subject_claim_keys
    ready_role_arn     = aws_iam_role.github_actions.arn
  }
}
