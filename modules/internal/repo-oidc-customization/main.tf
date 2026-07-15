locals {
  github_repository  = var.role_configurations[0].github_repository
  repository_name    = split("/", local.github_repository)[1]
  include_claim_keys = var.role_configurations[0].include_claim_keys
  ready_role_arns    = sort(distinct([for configuration in var.role_configurations : configuration.ready_role_arn]))
}

# This barrier makes each role ARN an explicit dependency of the repository-wide
# token-format change. GitHub therefore changes subjects only after every trust
# policy represented by role_configurations has been created or updated.
resource "terraform_data" "role_trust_policies_ready" {
  input = local.ready_role_arns
}

resource "github_actions_repository_oidc_subject_claim_customization_template" "workflow" {
  repository         = local.repository_name
  use_default        = false
  include_claim_keys = local.include_claim_keys

  depends_on = [terraform_data.role_trust_policies_ready]
}
