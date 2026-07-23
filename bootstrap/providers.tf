provider "aws" {
  region = var.aws_region
}

provider "github" {
  owner = split("/", var.github_repository)[0]
}
