# github-actions-aws-role deploy permissions

Produces IAM policy JSON for deploying the paired
`modules/internal/github-actions-aws-role` module. It follows the repository's
standard lifecycle outputs: `plan`, `create`, `update`, `destroy`, and `all`.

## Usage

```hcl
module "role_deploy_permissions" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//deploy-permissions/internal/github-actions-aws-role"

  role_name = "example-deployer"
  managed_policy_arns = {
    shared-read = aws_iam_policy.shared_read.arn
  }
}
```

Each output is a JSON string suitable for an IAM policy resource. Pass the same
`role_name`, `managed_policy_arns`, and `force_detach_policies` values to this
module and the paired infrastructure module.

## Scoping

- Role operations target the exact role ARN in the current AWS account and
  partition.
- Managed policy attachment and normal detachment are restricted by
  `iam:PolicyARN` to configured managed policies.
- If `force_detach_policies` is true, destroy/update permissions allow
  unrestricted `DetachRolePolicy` only on that exact role. This is required to
  remove policies attached outside Terraform before role deletion.
- The module does not grant `iam:PassRole` or workload runtime permissions.

The paired infrastructure module also publishes the role ARN as a GitHub
Actions repository secret. These AWS IAM policies do not authorize that GitHub
API operation; configure the GitHub provider separately with permission to
manage Actions secrets in the target repository.

There is no AWS deploy-permissions companion for
`repo-oidc-customization`; that module requires GitHub API authorization rather
than AWS IAM authorization.
