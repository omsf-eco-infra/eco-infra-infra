output "plan" {
  description = "IAM policy JSON for planning GitHub OIDC provider changes."
  value       = jsonencode(local.policies.plan)
}

output "create" {
  description = "IAM policy JSON for creating the GitHub OIDC provider."
  value       = jsonencode(local.policies.create)
}

output "update" {
  description = "IAM policy JSON for updating the GitHub OIDC provider."
  value       = jsonencode(local.policies.update)
}

output "destroy" {
  description = "IAM policy JSON for destroying the GitHub OIDC provider."
  value       = jsonencode(local.policies.destroy)
}

output "all" {
  description = "IAM policy JSON for all GitHub OIDC provider lifecycle operations."
  value       = jsonencode(local.policies.all)
}
