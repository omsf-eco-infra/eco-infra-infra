module "repository_customization" {
  source = "../../../../modules/internal/repo-oidc-customization"

  role_configurations = [{
    github_repository  = "example-org/example-repo"
    include_claim_keys = ["repo", "context", "workflow_ref"]
    ready_role_arn     = "arn:aws:iam::123456789012:role/compatibility-test-role"
  }]
}
