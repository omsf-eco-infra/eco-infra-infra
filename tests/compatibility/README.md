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
consistent with the child modules' committed constraints. Neither profile has a
committed dependency lock file.

## Consumer fixtures

The four roots cover:

- GitHub's AWS OIDC provider composed with its deployment permissions;
- the AWS state backend composed with its deployment permissions;
- the GitHub Actions AWS role composed with its deployment permissions; and
- repository OIDC customization by itself, allowing its GitHub provider floor
  to be tested independently from the role module.

CI discovers every fixture directory in both provider-profile matrix entries.
The minimum-provider entry requires `minimum/providers.tf`, verifies that no
`minimum_override.tf` already exists, and copies the profile to that ignored
override filename. The latest-provider entry skips the copy. Both entries
initialize with `-upgrade`, share a provider cache within the job, and run
`tofu init -backend=false` followed by `tofu validate` for each fixture.

## Running locally

OpenTofu must be on `PATH`. Provider resolution requires network access but no
AWS or GitHub credentials.

Run a minimum-provider check by temporarily installing the fixture's exact
profile as an override:

```console
fixture=tests/compatibility/fixtures/github-oidc
cp "$fixture/minimum/providers.tf" "$fixture/minimum_override.tf"
TF_DATA_DIR=/tmp/eco-infra-compatibility-minimum \
  tofu -chdir="$fixture" init -backend=false -input=false
TF_DATA_DIR=/tmp/eco-infra-compatibility-minimum \
  tofu -chdir="$fixture" validate
rm "$fixture/minimum_override.tf" "$fixture/.terraform.lock.hcl"
```

For latest-compatible providers, omit the override and request an upgrade:

```console
fixture=tests/compatibility/fixtures/github-oidc
TF_DATA_DIR=/tmp/eco-infra-compatibility-latest \
  tofu -chdir="$fixture" init -backend=false -input=false -upgrade
TF_DATA_DIR=/tmp/eco-infra-compatibility-latest \
  tofu -chdir="$fixture" validate
rm "$fixture/.terraform.lock.hcl"
```

Repeat those commands with each fixture directory. Set `TF_PLUGIN_CACHE_DIR` to
reuse a provider cache. To reproduce CI's OpenTofu endpoint, place OpenTofu
1.10.0 first on `PATH`.

## CI coverage

Pull requests, pushes to `main`, and manual workflow runs validate both provider
profiles with OpenTofu 1.10.0:

- minimum OpenTofu with the exact minimum providers; and
- minimum OpenTofu with the latest-compatible providers.

The two matrix entries run in parallel. Fixtures run serially inside named log
groups, so a failure identifies the affected consumer directly. The separate
fast-test job uses the latest OpenTofu release and latest-compatible providers
to initialize, validate, and run the full mocked module and contract test
suite. The `tofu init` output records the selected provider versions for
reproducing a failure caused by a floating provider endpoint.

Raising the minimum OpenTofu version, changing provider major-version bounds,
or removing a compatibility profile changes the repository's compatibility
policy and should be reviewed as such.
