locals {
  bucket_arn = "arn:aws:s3:::${var.bucket_name}"
  object_arn = "${local.bucket_arn}/*"

  statements = {
    discovery = {
      Sid    = "S3BucketDiscovery"
      Effect = "Allow"
      Action = [
        "s3:ListAllMyBuckets",
      ]
      Resource = ["*"]
    }

    bucket_read = {
      Sid    = "TfstateBucketRead"
      Effect = "Allow"
      Action = [
        "s3:GetBucketLocation",
        "s3:GetBucketPublicAccessBlock",
        "s3:GetBucketVersioning",
        "s3:GetEncryptionConfiguration",
        "s3:GetLifecycleConfiguration",
        "s3:ListBucket",
      ]
      Resource = [local.bucket_arn]
    }

    bucket_create = {
      Sid    = "TfstateBucketCreate"
      Effect = "Allow"
      Action = [
        "s3:CreateBucket",
      ]
      Resource = [local.bucket_arn]
    }

    bucket_mutation = {
      Sid    = "TfstateBucketMutation"
      Effect = "Allow"
      Action = [
        "s3:PutBucketPublicAccessBlock",
        "s3:PutBucketVersioning",
        "s3:PutEncryptionConfiguration",
        "s3:PutLifecycleConfiguration",
      ]
      Resource = [local.bucket_arn]
    }

    object_cleanup = {
      Sid    = "TfstateObjectCleanup"
      Effect = "Allow"
      Action = [
        "s3:DeleteObject",
        "s3:DeleteObjectVersion",
      ]
      Resource = [local.object_arn]
    }

    bucket_destroy = {
      Sid    = "TfstateBucketDestroy"
      Effect = "Allow"
      Action = [
        "s3:DeleteBucket",
        "s3:ListBucketVersions",
      ]
      Resource = [local.bucket_arn]
    }
  }

  policies = {
    plan = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.bucket_read,
      ]
    }

    create = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.bucket_read,
        local.statements.bucket_create,
        local.statements.bucket_mutation,
      ]
    }

    update = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.bucket_read,
        local.statements.bucket_mutation,
      ]
    }

    destroy = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.bucket_read,
        local.statements.bucket_mutation,
        local.statements.object_cleanup,
        local.statements.bucket_destroy,
      ]
    }

    all = {
      Version = "2012-10-17"
      Statement = [
        local.statements.discovery,
        local.statements.bucket_read,
        local.statements.bucket_create,
        local.statements.bucket_mutation,
        local.statements.object_cleanup,
        local.statements.bucket_destroy,
      ]
    }
  }
}
