# repo-oidc-customization

Configures one GitHub repository to emit OIDC subjects containing `repo`,
`context`, and caller `workflow_ref`. It consumes readiness contracts from all
of the repository's `github-actions-aws-role` modules.

The dependency direction is deliberate: AWS trust policies are created or
updated before GitHub changes the token format.

## Usage

```hcl
provider "github" {
  owner = "example-org"
}

module "deploy_role" {
  source = "../github-actions-aws-role"
  # Role inputs omitted.
}

module "test_role" {
  source = "../github-actions-aws-role"
  # Role inputs omitted.
}

module "repository_oidc" {
  source = "github.com/omsf-eco-infra/eco-infra-infra//modules/internal/repo-oidc-customization"

  role_configurations = [
    module.deploy_role.repository_oidc_configuration,
    module.test_role.repository_oidc_configuration,
  ]
}
```

All contracts must name the same repository and provide the same ordered claim
keys. The GitHub provider must be configured for that repository's owner. The
module passes the agreed claim keys through to GitHub rather than defining a
second copy of the role module's subject format.

## Ordering

Within one Terraform graph, the role ARNs form an explicit dependency barrier,
so the repository customization waits for every listed role. When roles and
the repository setting use different states, apply all role states first.

Do not omit a role that still receives OIDC tokens from the repository. The
template is repository-wide, and changing it can prevent omitted roles from
being assumed.

On destruction, Terraform removes the repository customization before the
roles it depends on. This safely stops customized tokens from matching before
the corresponding roles disappear.

## Inputs and outputs

`role_configurations` is a non-empty list of contracts output by
`github-actions-aws-role`. Each contains:

- `github_repository`
- `include_claim_keys`
- `ready_role_arn`

The module outputs `github_repository`, `include_claim_keys`, and
`customization_id`.

## Immutable subjects

V1 supports existing name-based GitHub OIDC subjects only. GitHub's immutable
subject format adds numeric owner and repository IDs, while the GitHub
Terraform provider does not yet manage the corresponding
`use_immutable_subject` setting end to end. Do not use this module for a
repository emitting immutable subjects until that support is added. GitHub
begins enabling immutable subjects by default for repositories created on or
after July 15, 2026.

See GitHub's [OIDC reference](https://docs.github.com/en/actions/reference/security/oidc)
for subject customization and immutable-subject behavior.
