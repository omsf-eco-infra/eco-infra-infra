#!/usr/bin/env bash

set -uo pipefail

if (($# != 1)) || [[ "$1" != "minimum" && "$1" != "latest" ]]; then
  echo "Usage: $0 <minimum|latest>" >&2
  exit 2
fi

provider_profile=$1
script_directory=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repository_root=$(cd -- "$script_directory/../.." && pwd)
work_root=$(mktemp -d "${TMPDIR:-/tmp}/eco-infra-compatibility.XXXXXX")
work_repository="$work_root/repository"
plugin_cache_directory=${TF_PLUGIN_CACHE_DIR:-"$work_root/plugin-cache"}

cleanup() {
  rm -rf -- "$work_root"
}
trap cleanup EXIT

mkdir -p "$work_repository/tests/compatibility/fixtures" "$plugin_cache_directory"
ln -s "$repository_root/modules" "$work_repository/modules"
ln -s "$repository_root/deploy-permissions" "$work_repository/deploy-permissions"

shopt -s nullglob
fixture_directories=("$script_directory"/fixtures/*/)
if ((${#fixture_directories[@]} == 0)); then
  echo "No compatibility fixtures found under $script_directory/fixtures" >&2
  exit 1
fi

tofu_version=$(tofu version | sed -n '1p')
echo "$tofu_version"
echo "Provider profile: $provider_profile"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    echo "## Compatibility: $provider_profile providers"
    echo
    echo "OpenTofu: \`$tofu_version\`"
    echo
    echo "| Fixture | Resolved providers | Result |"
    echo "| --- | --- | --- |"
  } >> "$GITHUB_STEP_SUMMARY"
fi

record_result() {
  local fixture=$1
  local providers=$2
  local result=$3

  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    echo "| \`$fixture\` | \`$providers\` | $result |" >> "$GITHUB_STEP_SUMMARY"
  fi
}

fail_fixture() {
  local fixture=$1
  local stage=$2

  record_result "$fixture" "Not resolved" "$stage failed"
  if [[ "${GITHUB_ACTIONS:-false}" == "true" ]]; then
    echo "::error title=Compatibility $stage failed::$fixture ($provider_profile providers)"
  fi
  exit 1
}

for source_fixture in "${fixture_directories[@]}"; do
  source_fixture=${source_fixture%/}
  fixture=${source_fixture##*/}
  echo "::group::$fixture ($provider_profile providers)"

  working_fixture="$work_repository/tests/compatibility/fixtures/$fixture"
  data_directory="$work_root/data/$fixture"
  minimum_providers="$source_fixture/minimum/providers.tf"

  mkdir -p "$working_fixture" "$data_directory"
  cp "$source_fixture/main.tf" "$source_fixture/versions.tofu" "$working_fixture/"

  if [[ ! -f "$minimum_providers" ]]; then
    echo "Missing minimum provider profile: $minimum_providers" >&2
    echo "::endgroup::"
    fail_fixture "$fixture" "Minimum provider profile"
  fi

  if [[ "$provider_profile" == "minimum" ]]; then
    cp "$minimum_providers" "$working_fixture/providers.tf"
  fi

  init_arguments=(-backend=false -input=false -no-color)
  if [[ "$provider_profile" == "latest" ]]; then
    init_arguments+=(-upgrade)
  fi

  if ! TF_DATA_DIR="$data_directory" TF_PLUGIN_CACHE_DIR="$plugin_cache_directory" \
    tofu -chdir="$working_fixture" init "${init_arguments[@]}"; then
    echo "::endgroup::"
    fail_fixture "$fixture" "Initialization"
  fi

  if ! TF_DATA_DIR="$data_directory" TF_PLUGIN_CACHE_DIR="$plugin_cache_directory" \
    tofu -chdir="$working_fixture" validate -no-color; then
    echo "::endgroup::"
    fail_fixture "$fixture" "Validation"
  fi

  resolved_providers=$(awk '
    /^provider "/ {
      provider = $2
      gsub(/"/, "", provider)
    }
    /^  version[[:space:]]*= "/ {
      version = $3
      gsub(/"/, "", version)
      if (resolved != "") {
        resolved = resolved ", "
      }
      resolved = resolved provider "=" version
    }
    END { print resolved }
  ' "$working_fixture/.terraform.lock.hcl")

  echo "Resolved providers: $resolved_providers"
  record_result "$fixture" "$resolved_providers" "Passed"
  echo "::endgroup::"
done

echo "All compatibility fixtures passed with $provider_profile providers."
