# Deploy Permissions

This directory contains Terraform modules that publish deploy-time permissions
for the infrastructure modules in `modules/`.

AWS resource modules mirror `modules/` one-for-one:

- `modules/foo` pairs with `deploy-permissions/foo`

Modules that only configure another provider do not receive an AWS IAM
deploy-permissions companion. For example,
`modules/internal/repo-oidc-customization` uses GitHub API authorization.

Each deploy-permissions module exposes the same five outputs:

- `plan`
- `create`
- `update`
- `destroy`
- `all`

Each output is an IAM policy document JSON string intended to be attached
directly to a role or wrapped in an `aws_iam_policy` resource, for example:

```hcl
module "backend_permissions" {
  source = "../../deploy-permissions/tfstate-aws-backend"

  bucket_name = "example-tfstate-bucket"
}

resource "aws_iam_policy" "backend_create" {
  name   = "backend-create"
  policy = module.backend_permissions.create
}
```

The outputs are scoped by lifecycle phase:

- `plan`: read and discovery permissions only
- `create`: `plan` plus create-time mutation permissions
- `update`: `plan` plus update-time mutation permissions
- `destroy`: `plan` plus teardown permissions
- `all`: the deduplicated union of `create`, `update`, and `destroy`

Some infrastructure modules may intentionally use controls such as
`prevent_destroy`. The matching deploy-permissions module should still publish a
`destroy` policy so operators have a documented, explicit permission set for
controlled teardown after configuration changes or intentional lifecycle
overrides.

These modules describe permissions needed to deploy and manage infrastructure.
They do not automatically describe the runtime permissions required to use the
resulting resources after they have been created.
