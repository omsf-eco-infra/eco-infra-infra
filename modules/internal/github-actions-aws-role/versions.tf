terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.2.0, < 5.0.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.12.0"
    }
  }
}
