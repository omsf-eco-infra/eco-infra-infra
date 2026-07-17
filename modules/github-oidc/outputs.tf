output "github_oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider in IAM."
  value = one(concat(
    aws_iam_openid_connect_provider.github[*].arn,
    aws_iam_openid_connect_provider.github_destroyable[*].arn,
  ))
}
