terraform {
  backend "s3" {
    # details are provided in the backend.hcl file; use `init
    # -backend-condig backend.hcl` to initialize
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


