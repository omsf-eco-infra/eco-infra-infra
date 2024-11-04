variable "aws_region" {
  type        = string
  description = "AWS region"
}

variable "bucket_name" {
  type        = string
  description = "Name of the S3 bucket to store the Terraform state file"
}

