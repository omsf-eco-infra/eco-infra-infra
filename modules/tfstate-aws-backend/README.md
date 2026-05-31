# tfstate-aws-backend

Creates an AWS S3 bucket suitable for use as a Terraform/OpenTofu remote state
backend.

The module creates:

- An S3 bucket with `prevent_destroy`
- Bucket versioning
- Default server-side encryption with SSE-S3 (`AES256`)
- Public access blocking
- A lifecycle rule that expires noncurrent object versions after 90 days

Backend locking is expected to use the S3 backend's native lockfile support via
`use_lockfile = true`.

## Requirements

- Terraform >= 1.10 or OpenTofu >= 1.10 for the S3 backend `use_lockfile` option
- AWS provider `~> 4.0`

## Inputs

| Name | Type | Description |
| --- | --- | --- |
| `bucket_name` | `string` | Name of the S3 bucket that will store state |

## Deploy The Backend Bucket

Create this bucket from a separate bootstrap stack. Do not configure the stack
that creates the bucket to also store its own state in that same bucket.

Example:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  # Configure the AWS provider as appropriate for the account and region
  # where this bucket should be created.
}

module "remote_state" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//modules/tfstate-aws-backend"

  bucket_name = var.bucket_name
}
```

Minimal variables:

```hcl
bucket_name = "my-tfstate-bucket"
```

Typical bootstrap flow:

```sh
tofu init
tofu plan -var-file=backend.tfvars
tofu apply -var-file=backend.tfvars
```

If you use Terraform instead of OpenTofu, substitute `terraform` for `tofu`.

## Use The Bucket As A Backend Elsewhere

After the bucket exists, configure other Terraform/OpenTofu stacks to use it as
their backend. Those consumer stacks should be managed separately from the
bootstrap stack that created the bucket.

Minimal backend block:

```hcl
terraform {
  backend "s3" {
    encrypt      = true
    use_lockfile = true
  }
}
```

Example `backend.hcl`:

```hcl
bucket       = "my-tfstate-bucket"
region       = "us-east-1"
key          = "networking/prod/terraform.tfstate"
encrypt      = true
use_lockfile = true
```

Initialize the consumer stack with:

```sh
tofu init -reconfigure -backend-config=backend.hcl
```

## Operational Notes

- Changing backend settings requires `tofu init -reconfigure` or
  `terraform init -reconfigure`.
- The principal using the backend needs S3 access to the state object and the
  lockfile object created alongside it.
- Bucket versioning is enabled for state recovery. The lifecycle rule limits
  growth in noncurrent versions, including versions created by frequent state
  updates and lockfile churn.
