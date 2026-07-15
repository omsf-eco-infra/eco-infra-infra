terraform {
  required_version = ">= 1.4.0"

  backend "s3" {
    key          = "eco-infra-infra-tests/bootstrap/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
    github = {
      source  = "integrations/github"
      version = ">= 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "github" {
  owner = split("/", var.github_repository)[0]
}
