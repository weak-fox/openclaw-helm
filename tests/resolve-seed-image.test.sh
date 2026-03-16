#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="$repo_root/.github/scripts/resolve-seed-image.sh"

assert_outputs() {
  local label="$1"
  local target_version="$2"
  local input_seed_semver="$3"
  local releases_json="$4"
  local image_exists="$5"
  local expected_semver="$6"
  local expected_tag="$7"
  local expected_image="$8"
  local expected_exists="$9"
  local expected_reason="${10}"
  local tmpdir output_file stdout_file actual_semver actual_tag actual_image actual_exists actual_reason

  tmpdir="$(mktemp -d)"
  output_file="$tmpdir/github-output"
  stdout_file="$tmpdir/stdout"

  if ! TARGET_VERSION="$target_version" \
    INPUT_SEED_SEMVER="$input_seed_semver" \
    INPUT_SEED_IMAGE_REPO="ghcr.io/weak-fox/openclaw-offline-seed" \
    SEED_RELEASES_JSON="$releases_json" \
    SEED_IMAGE_EXISTS="$image_exists" \
    GITHUB_OUTPUT="$output_file" \
    "$script_path" >"$stdout_file" 2>&1; then
    echo "FAIL: $label"
    cat "$stdout_file"
    rm -rf "$tmpdir"
    exit 1
  fi

  actual_semver="$(sed -n 's/^semver=//p' "$output_file")"
  actual_tag="$(sed -n 's/^tag=//p' "$output_file")"
  actual_image="$(sed -n 's/^image=//p' "$output_file")"
  actual_exists="$(sed -n 's/^exists=//p' "$output_file")"
  actual_reason="$(sed -n 's/^reason=//p' "$output_file")"

  if [ "$actual_semver" != "$expected_semver" ] \
    || [ "$actual_tag" != "$expected_tag" ] \
    || [ "$actual_image" != "$expected_image" ] \
    || [ "$actual_exists" != "$expected_exists" ] \
    || [ "$actual_reason" != "$expected_reason" ]; then
    echo "FAIL: $label"
    echo "Expected semver=$expected_semver tag=$expected_tag image=$expected_image exists=$expected_exists reason=$expected_reason"
    echo "Actual   semver=$actual_semver tag=$actual_tag image=$actual_image exists=$actual_exists reason=$actual_reason"
    cat "$stdout_file"
    rm -rf "$tmpdir"
    exit 1
  fi

  rm -rf "$tmpdir"
}

assert_outputs \
  "latest matching seed release is selected for the OpenClaw version suffix" \
  "2026.3.13-1" \
  "" \
  '[{"tag_name":"v1.0.4-oc-2026.3.13-1","prerelease":false,"draft":false},{"tag_name":"v1.0.3-oc-2026.3.12","prerelease":false,"draft":false},{"tag_name":"v1.0.2-oc-2026.3.13-1","prerelease":false,"draft":false}]' \
  "true" \
  "1.0.4" \
  "v1.0.4-oc-2026.3.13-1" \
  "ghcr.io/weak-fox/openclaw-offline-seed:v1.0.4-oc-2026.3.13-1" \
  "true" \
  ""

assert_outputs \
  "manual seed semver override still works" \
  "2026.3.13-1" \
  "1.2.3" \
  '[]' \
  "true" \
  "1.2.3" \
  "v1.2.3-oc-2026.3.13-1" \
  "ghcr.io/weak-fox/openclaw-offline-seed:v1.2.3-oc-2026.3.13-1" \
  "true" \
  ""

assert_outputs \
  "missing matching seed release reports a clear reason" \
  "2026.3.13-1" \
  "" \
  '[{"tag_name":"v1.0.3-oc-2026.3.12","prerelease":false,"draft":false}]' \
  "false" \
  "" \
  "" \
  "" \
  "false" \
  "No seed release found matching OpenClaw version: 2026.3.13-1"

echo "All resolve-seed-image tests passed"
