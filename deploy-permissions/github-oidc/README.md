# github-oidc deploy permissions

This module emits IAM policy document JSON for deploying and managing the
paired `modules/github-oidc` module.

## Input

This module has no inputs.

## Outputs

| Name | Type | Description |
| --- | --- | --- |
| `plan` | `string` | IAM policy JSON for read and discovery access |
| `create` | `string` | IAM policy JSON for creating the GitHub OIDC provider |
| `update` | `string` | IAM policy JSON for updating the GitHub OIDC provider configuration |
| `destroy` | `string` | IAM policy JSON for deleting the GitHub OIDC provider |
| `all` | `string` | IAM policy JSON containing the deduplicated union of all lifecycle permissions |

## Scope

The generated policies are intentionally limited to deploy-time management of
the account's GitHub Actions OIDC provider at:

- `arn:${partition}:iam::${account_id}:oidc-provider/token.actions.githubusercontent.com`

Lifecycle access is split as follows:

- `plan`: `iam:ListOpenIDConnectProviders` on `*` plus
  `iam:GetOpenIDConnectProvider` on the exact provider ARN
- `create`: `plan` plus `iam:CreateOpenIDConnectProvider`
- `update`: `plan` plus `iam:AddClientIDToOpenIDConnectProvider`,
  `iam:RemoveClientIDFromOpenIDConnectProvider`, and
  `iam:UpdateOpenIDConnectProviderThumbprint`
- `destroy`: `plan` plus `iam:DeleteOpenIDConnectProvider`
- `all`: union of `create`, `update`, and `destroy`

These policies cover deployment and lifecycle management only. They do not
grant runtime permissions for GitHub Actions or define IAM role trust policies
that use this OIDC provider.
