terraform {
  required_version = ">= 1.10.0"

  required_providers {
    # First provider version with the required repository OIDC schema.
    github = {
      source  = "integrations/github"
      version = ">= 5.14.0"
    }
  }
}
