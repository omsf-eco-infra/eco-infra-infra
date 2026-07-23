terraform {
  required_version = ">= 1.10.0"

  required_providers {
    # aws_iam_openid_connect_provider data source support begins at 4.2.0.
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.2.0, < 5.0.0"
    }
    # github_actions_secret.value requires 6.12.0 or newer.
    github = {
      source  = "integrations/github"
      version = ">= 6.12.0"
    }
  }
}
