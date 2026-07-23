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

Each fixture commits an exact minimum-provider profile under
`minimum/providers.tf`. The latest-compatible profile omits those root
constraints and lets OpenTofu select the newest versions allowed by the child
modules:

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

The exact minimum profiles are reviewed compatibility-policy inputs. They must
list every provider in the fixture's transitive module graph and remain
consistent with the child modules' committed constraints. The runner copies a
fixture and its selected profile to temporary storage before initialization.
Neither profile has a committed dependency lock file.

## Consumer fixtures

The four roots cover:

- GitHub's AWS OIDC provider composed with its deployment permissions;
- the AWS state backend composed with its deployment permissions;
- the GitHub Actions AWS role composed with its deployment permissions; and
- repository OIDC customization by itself, allowing its GitHub provider floor
  to be tested independently from the role module.

The runner copies each root into a temporary repository-shaped directory. For
the minimum profile it copies `minimum/providers.tf` into the root as
`providers.tf`; for the latest profile it omits that file and initializes with
`-upgrade`. It uses a separate OpenTofu data directory per fixture and a shared
provider cache, then runs `tofu init -backend=false` and `tofu validate`
serially. Temporary lock files and downloaded metadata are deleted on exit,
leaving the checkout unchanged.

## Running locally

OpenTofu must be on `PATH`. Provider resolution requires network access but no
AWS or GitHub credentials.

```console
tests/compatibility/run.sh minimum
tests/compatibility/run.sh latest
```

Set `TF_PLUGIN_CACHE_DIR` to reuse an existing provider cache:

```console
TF_PLUGIN_CACHE_DIR=/tmp/eco-infra-provider-cache tests/compatibility/run.sh latest
```

To test with OpenTofu 1.10, place that version first on `PATH`:

```console
PATH=/path/to/tofu-1.10:$PATH tests/compatibility/run.sh minimum
```

The runner requires every fixture to contain `minimum/providers.tf`. It prints
the OpenTofu version, fixture name, stage, and exact resolved provider versions,
and exits at the first missing profile, initialization failure, or validation
failure.

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
