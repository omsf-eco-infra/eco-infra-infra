output "plan" {
  description = "IAM policy JSON for planning GitHub Actions role changes."
  value       = jsonencode(local.policies.plan)
}

output "create" {
  description = "IAM policy JSON for creating the GitHub Actions role and its policies."
  value       = jsonencode(local.policies.create)
}

output "update" {
  description = "IAM policy JSON for updating the GitHub Actions role and its policies."
  value       = jsonencode(local.policies.update)
}

output "destroy" {
  description = "IAM policy JSON for destroying the GitHub Actions role and its policies."
  value       = jsonencode(local.policies.destroy)
}

output "all" {
  description = "IAM policy JSON for all GitHub Actions role lifecycle operations."
  value       = jsonencode(local.policies.all)
}
