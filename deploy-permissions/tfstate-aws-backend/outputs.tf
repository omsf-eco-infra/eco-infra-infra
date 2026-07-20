output "plan" {
  description = "IAM policy JSON for planning tfstate backend bucket changes."
  value       = jsonencode(local.policies.plan)
}

output "create" {
  description = "IAM policy JSON for creating the tfstate backend bucket."
  value       = jsonencode(local.policies.create)
}

output "update" {
  description = "IAM policy JSON for updating the tfstate backend bucket."
  value       = jsonencode(local.policies.update)
}

output "destroy" {
  description = "IAM policy JSON for destroying the tfstate backend bucket."
  value       = jsonencode(local.policies.destroy)
}

output "all" {
  description = "IAM policy JSON for all tfstate backend bucket lifecycle operations."
  value       = jsonencode(local.policies.all)
}
