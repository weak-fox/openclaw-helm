#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script_path="$repo_root/.github/scripts/resolve-openclaw-version.sh"

assert_resolves() {
  local label="$1"
  local input_version="$2"
  local release_json="$3"
  local expected="$4"
  local tmpdir output_file stdout_file actual

  tmpdir="$(mktemp -d)"
  output_file="$tmpdir/github-output"
  stdout_file="$tmpdir/stdout"

  if ! INPUT_VERSION="$input_version" \
    RELEASE_JSON="$release_json" \
    GITHUB_OUTPUT="$output_file" \
    "$script_path" >"$stdout_file" 2>&1; then
    echo "FAIL: $label"
    cat "$stdout_file"
    rm -rf "$tmpdir"
    exit 1
  fi

  actual="$(sed -n 's/^version=//p' "$output_file")"
  if [ "$actual" != "$expected" ]; then
    echo "FAIL: $label"
    echo "Expected version=$expected"
    echo "Actual version=${actual:-<empty>}"
    cat "$stdout_file"
    rm -rf "$tmpdir"
    exit 1
  fi

  rm -rf "$tmpdir"
}

assert_fails() {
  local label="$1"
  local input_version="$2"
  local release_json="$3"
  local tmpdir output_file stdout_file

  tmpdir="$(mktemp -d)"
  output_file="$tmpdir/github-output"
  stdout_file="$tmpdir/stdout"

  if INPUT_VERSION="$input_version" \
    RELEASE_JSON="$release_json" \
    GITHUB_OUTPUT="$output_file" \
    "$script_path" >"$stdout_file" 2>&1; then
    echo "FAIL: $label"
    echo "Expected resolver to fail"
    cat "$stdout_file"
    rm -rf "$tmpdir"
    exit 1
  fi

  rm -rf "$tmpdir"
}

assert_resolves \
  "latest release title wins over recovery tag suffix" \
  "" \
  '{"name":"openclaw 2026.3.13","tag_name":"v2026.3.13-1"}' \
  "2026.3.13"

assert_resolves \
  "manual stable version passes through" \
  "2026.3.13" \
  "" \
  "2026.3.13"

assert_resolves \
  "manual recovery tag normalizes to the deployable version" \
  "2026.3.13-1" \
  "" \
  "2026.3.13"

assert_fails \
  "beta prerelease does not resolve as a stable release" \
  "" \
  '{"name":"openclaw 2026.3.13-beta.1","tag_name":"v2026.3.13-beta.1"}'

echo "All resolve-openclaw-version tests passed"
