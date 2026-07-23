# Compatibility tests

These tests exercise the committed modules through minimal external consumer
roots. The roots declare compatibility with Terraform and OpenTofu, but this
suite currently uses OpenTofu only. It checks that the supported OpenTofu and
provider endpoints can initialize and validate the public module interfaces
without cloud credentials. The uncommitted Cloudflare backend is outside this
suite.

## Supported versions

The modules and consumer roots declare Terraform and OpenTofu 1.10.0 as their
shared minimum in `versions.tf`. CI pins the tested minimum endpoint to
OpenTofu `1.10.0`. The fast-test job passes `latest` to
`opentofu/setup-opentofu`; it is resolved when the job starts and selects the
latest stable OpenTofu release. Terraform compatibility is intended but not
currently tested.

Each fixture commits an exact minimum-provider profile under
`minimum/providers.tf`. The latest-compatible profile omits those root
constraints and lets OpenTofu select the newest versions allowed by the child
modules.

The exact minimum profiles are reviewed compatibility-policy inputs. They must
list every provider in the fixture's transitive module graph and remain
consistent with the child modules' committed constraints. Neither profile has a
committed dependency lock file.

## Consumer fixtures

Each fixture is a minimal external consumer of a supported module graph. CI
discovers every fixture directory in both provider-profile matrix entries. The
minimum-provider entry requires `minimum/providers.tf`, verifies that no
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

Raising the shared Terraform/OpenTofu minimum, changing provider major-version
bounds, or removing a compatibility profile changes the repository's
compatibility policy and should be reviewed as such.
