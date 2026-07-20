# tfstate-aws-backend deploy permissions

This module emits IAM policy document JSON for deploying and managing the
paired `modules/tfstate-aws-backend` module.

## Input

| Name | Type | Description |
| --- | --- | --- |
| `bucket_name` | `string` | Name of the S3 bucket managed by the paired infra module |

## Outputs

| Name | Type | Description |
| --- | --- | --- |
| `plan` | `string` | IAM policy JSON for read and discovery access |
| `create` | `string` | IAM policy JSON for creating the bucket and configuring it |
| `update` | `string` | IAM policy JSON for updating bucket configuration |
| `destroy` | `string` | IAM policy JSON for emptying and deleting the bucket |
| `all` | `string` | IAM policy JSON containing the deduplicated union of all lifecycle permissions |

## Scope

The generated policies are intentionally limited to deploy-time management of
the backend bucket:

- Global discovery: `s3:ListAllMyBuckets`
- Bucket reads: `s3:ListBucket`, `s3:GetBucketLocation`,
  `s3:GetBucketVersioning`, `s3:GetEncryptionConfiguration`,
  `s3:GetBucketPublicAccessBlock`, and `s3:GetLifecycleConfiguration`
- Bucket mutation: `s3:CreateBucket`, `s3:PutBucketVersioning`,
  `s3:PutEncryptionConfiguration`, `s3:PutBucketPublicAccessBlock`, and
  `s3:PutLifecycleConfiguration`
- Destroy cleanup: `s3:DeleteBucket`, `s3:ListBucketVersions`,
  `s3:DeleteObject`, and `s3:DeleteObjectVersion`

`destroy` includes cleanup permissions for bucket objects and versions so a
populated state bucket can be removed during an intentional teardown workflow.
This module does not include the runtime permissions needed to use the bucket as
an OpenTofu or Terraform backend after it exists.
