output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider in IAM."
  value       = aws_iam_openid_connect_provider.github.arn
}
