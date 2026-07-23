# eco-infra-infra

*Infrastructure modules by OMSF's Ecosystem Infrastructure team.*

In the course of our work building out various cloud-based tools for OMSF and beyond, we have found ourselves repeating a number of patterns in our infrastructure code.
This repository is an attempt to capture those patterns in reusable modules.
On one hand, this is a standard "don't repeat yourself" effort, intended to reduce our maintenance burden by centralizing common code in one place.
On the other hand, we hope this repository can be useful as part of our efforts to teach infrastructure as code to other OMSF developers, by providing examples of what simple reusable components look like.

## Structure

* `modules/`: This directory contains the reusable modules themselves.

See [Adding Modules](ADDING_MODULES.md) for the required module structure,
compatibility policy, test layers, and repository integration checklist.

## Modules

### End-User Modules

A few of our modules are intended to be used directly by end-users, rather than being building blocks for other tools.

* `github-oidc`: A module to create the AWS IAM OpenID Connect provider for GitHub Actions.
* `tfstate-aws-backend`: A module to create a Terraform state bucket in AWS.

### Building Block Modules

These modules are intended to be used as building blocks for other tools, and are likely to be reused across many projects.

* `internal/github-actions-aws-role`: A workflow-scoped AWS IAM role for GitHub Actions, with caller-provided policies.
* `internal/repo-oidc-customization`: Repository-wide GitHub OIDC subject customization coordinated across all of a repository's AWS roles.

## Compatibility policy

Committed modules support OpenTofu 1.10.0 and newer. Continuous integration
keeps 1.10.0 as the fixed minimum endpoint and resolves `latest` at job runtime
for the current endpoint, so updating the current OpenTofu version does not
require a repository commit.

Provider compatibility is bounded by each module's `required_providers`
constraints. The tested provider floors are:

| Module | AWS provider | GitHub provider |
| --- | --- | --- |
| `github-oidc` | 4.0.0 (4.x) | Not used |
| `tfstate-aws-backend` | 4.0.0 (4.x) | Not used |
| `internal/github-actions-aws-role` | 4.2.0 (4.x) | 6.12.0 or newer |
| `internal/repo-oidc-customization` | Not used | 5.14.0 or newer |

See [the compatibility test documentation](tests/compatibility/README.md) for
the consumer fixtures, local commands, exact provider profiles, and CI
coverage. Raising the OpenTofu minimum, changing a provider major-version
bound, or dropping a compatibility profile is an intentional compatibility
decision.
