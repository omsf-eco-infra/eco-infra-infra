output "github_oidc_provider_arn" {
  description = "ARN of the account-wide GitHub Actions OIDC provider."
  value       = data.aws_iam_openid_connect_provider.github.arn
}

output "test_role_name" {
  description = "Name of the GitHub Actions test role."
  value       = module.test_role.role_name
}

output "test_role_arn" {
  description = "ARN of the GitHub Actions test role."
  value       = module.test_role.role_arn
}
