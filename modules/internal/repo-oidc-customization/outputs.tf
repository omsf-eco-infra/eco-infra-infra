output "github_repository" {
  description = "Repository whose OIDC subject template is customized."
  value       = local.github_repository
}

output "include_claim_keys" {
  description = "Ordered claims included in the customized OIDC subject."
  value       = github_actions_repository_oidc_subject_claim_customization_template.workflow.include_claim_keys
}

output "customization_id" {
  description = "GitHub repository OIDC customization resource identifier."
  value       = github_actions_repository_oidc_subject_claim_customization_template.workflow.id
}
