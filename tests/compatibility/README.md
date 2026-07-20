# Compatibility tests

These tests exercise the committed modules through minimal external consumer
roots. They check that the supported OpenTofu and provider endpoints can
initialize and validate the public module interfaces without cloud credentials.
The uncommitted Cloudflare backend is outside this suite.

## Supported versions

The minimum supported OpenTofu version is 1.10.0. CI pins that endpoint to
`1.10.0` and passes `latest` to `opentofu/setup-opentofu` for the current
endpoint. `latest` is resolved when a job starts and selects the latest stable
release; there is no periodically updated current-version pin in this
repository.

The generated provider profiles select these endpoints within the child
modules' constraints:

| Fixture | Minimum providers | Latest-compatible providers |
| --- | --- | --- |
| `github-oidc` | AWS 4.0.0 | Newest AWS 4.x |
| `tfstate-aws-backend` | AWS 4.0.0 | Newest AWS 4.x |
| `internal-github-actions-aws-role` | AWS 4.2.0 and GitHub 6.12.0 | Newest AWS 4.x and newest GitHub 6.x or newer |
| `repo-oidc-customization` | GitHub 5.14.0 | Newest GitHub 5.14.0 or newer |

The role module's AWS floor is 4.2.0 because its OIDC provider data source is
not available in AWS 4.0.0. Its GitHub floor is 6.12.0 because it uses the
current `github_actions_secret.value` argument. Repository OIDC customization
requires GitHub 5.14.0 because that is the first compatible provider schema for
its resource. Other committed AWS modules retain their `~> 4.0` constraint.

The profile generator uses `tofu show -module=DIR -json` to inspect every local
module in a consumer graph. It combines each provider's declared constraints
and selects the greatest inclusive lower bound. The minimum profile turns those
bounds into exact root constraints. The latest-compatible profile declares
only provider sources, leaving the child modules' committed constraints to
control selection. Neither profile has a committed lock file.

## Consumer fixtures

The four roots cover:

- GitHub's AWS OIDC provider composed with its deployment permissions;
- the AWS state backend composed with its deployment permissions;
- the GitHub Actions AWS role composed with its deployment permissions; and
- repository OIDC customization by itself, allowing its GitHub provider floor
  to be tested independently from the role module.

The runner copies each root into a temporary repository-shaped directory. It
uses a separate OpenTofu data directory per fixture and a shared provider cache,
then runs `tofu init -backend=false` and `tofu validate` serially. Temporary
lock files and downloaded metadata are deleted on exit, leaving the checkout
unchanged.

## Running locally

OpenTofu must be on `PATH`. Profile generation requires OpenTofu 1.11 or newer
for static module inspection, even when the generated profile will be tested
with OpenTofu 1.10. Set `TOFU_INSPECT` to a separate current OpenTofu binary in
that case. Provider resolution requires network access but no AWS or GitHub
credentials.

```console
tests/compatibility/run.sh minimum
tests/compatibility/run.sh latest
```

Set `TF_PLUGIN_CACHE_DIR` to reuse an existing provider cache:

```console
TF_PLUGIN_CACHE_DIR=/tmp/eco-infra-provider-cache tests/compatibility/run.sh latest
```

To test OpenTofu 1.10 with a separate inspection binary:

```console
TOFU_INSPECT=/path/to/current/tofu PATH=/path/to/tofu-1.10:$PATH \
  tests/compatibility/run.sh minimum
```

The generator rejects provider constraints without a statically derivable,
inclusive lower bound. The runner prints the OpenTofu version, fixture name,
stage, and exact resolved provider versions. It exits at the first failed
profile generation, initialization, or validation.

## CI matrix

Pull requests run the two endpoint combinations:

- OpenTofu 1.10.0 with minimum providers; and
- latest OpenTofu with latest-compatible providers.

Pushes to `main` and manual workflow runs add the cross-combinations:

- OpenTofu 1.10.0 with latest-compatible providers; and
- latest OpenTofu with minimum providers.

Matrix combinations run in parallel, while the four fixtures within a job run
serially. Every job summary records the resolved OpenTofu and provider versions.
A floating endpoint can therefore reveal an upstream incompatibility without a
repository change; use the recorded versions to reproduce that run.

Raising the minimum OpenTofu version, changing provider major-version bounds,
or removing a matrix combination changes the repository's compatibility policy
and should be reviewed as such.
