mock_provider "aws" {
  alias = "mock"
}

variables {
  bucket_name = "test-tfstate-bucket"
}

run "bucket_configuration" {
  command = plan
  providers = {
    aws = aws.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition     = aws_s3_bucket.tfstate.bucket == var.bucket_name
    error_message = "Bucket name should match the configured bucket_name."
  }

  assert {
    condition     = aws_s3_bucket_versioning.tfstate.versioning_configuration[0].status == "Enabled"
    error_message = "Bucket versioning should be enabled."
  }

  assert {
    condition     = one(one(aws_s3_bucket_server_side_encryption_configuration.default.rule).apply_server_side_encryption_by_default).sse_algorithm == "AES256"
    error_message = "Bucket encryption should default to AES256."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.public_access.block_public_acls
    error_message = "Public ACLs should be blocked."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.public_access.block_public_policy
    error_message = "Public bucket policies should be blocked."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.public_access.ignore_public_acls
    error_message = "Public ACLs should be ignored."
  }

  assert {
    condition     = aws_s3_bucket_public_access_block.public_access.restrict_public_buckets
    error_message = "Public buckets should be restricted."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.tfstate.rule[0].id == "expire-noncurrent-versions"
    error_message = "Lifecycle rule should use the expected identifier."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.tfstate.rule[0].status == "Enabled"
    error_message = "Lifecycle rule should be enabled."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.tfstate.rule[0].noncurrent_version_expiration[0].noncurrent_days == 90
    error_message = "Noncurrent object versions should expire after 90 days."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.tfstate.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    error_message = "Incomplete multipart uploads should be aborted after 7 days."
  }
}
