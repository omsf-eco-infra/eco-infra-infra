mock_provider "aws" {
  alias = "mock"
}

run "resource_and_permissions_contract" {
  command = plan

  providers = {
    aws = aws.mock
  }

  plan_options {
    refresh = false
  }

  assert {
    condition = alltrue([
      for statement in jsondecode(output.permissions_all).Statement :
      statement.Resource == (
        statement.Sid == "S3BucketDiscovery" ? ["*"] :
        statement.Sid == "TfstateObjectCleanup" ? ["arn:aws:s3:::${var.bucket_name}/*"] :
        ["arn:aws:s3:::${var.bucket_name}"]
      )
    ])
    error_message = "S3 permissions should use the configured bucket and object ARNs; only discovery may target all resources."
  }

  assert {
    condition = (
      contains(flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]), "s3:CreateBucket") &&
      !contains(flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]), "s3:DeleteBucket") &&
      contains(flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]), "s3:PutBucketVersioning") &&
      !contains(flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]), "s3:CreateBucket") &&
      contains(flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]), "s3:DeleteObjectVersion") &&
      contains(flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]), "s3:DeleteBucket")
    )
    error_message = "Create, update, and destroy policies should contain the required lifecycle-specific S3 mutations."
  }

  assert {
    condition = (
      length(distinct([for statement in jsondecode(output.permissions_all).Statement : statement.Sid])) == length(jsondecode(output.permissions_all).Statement) &&
      length(setsubtract(
        toset(concat(
          flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]),
        )),
        toset(flatten([for statement in jsondecode(output.permissions_all).Statement : statement.Action])),
      )) == 0 &&
      length(setsubtract(
        toset(flatten([for statement in jsondecode(output.permissions_all).Statement : statement.Action])),
        toset(concat(
          flatten([for statement in jsondecode(output.permissions_create).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_update).Statement : statement.Action]),
          flatten([for statement in jsondecode(output.permissions_destroy).Statement : statement.Action]),
        )),
      )) == 0
    )
    error_message = "The all policy should be the deduplicated union of create, update, and destroy permissions."
  }
}
