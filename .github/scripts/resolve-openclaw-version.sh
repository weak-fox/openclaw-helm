#!/usr/bin/env bash
set -euo pipefail

extract_version_token() {
  local text="$1"

  if [[ "$text" =~ (v?[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?) ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

normalize_target_version() {
  local raw="${1#v}"

  if [[ "$raw" =~ ^([0-9]+\.[0-9]+\.[0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  # Recovery releases may use git tags like v2026.3.13-1, but the app version stays 2026.3.13.
  if [[ "$raw" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi

  return 1
}

json_field() {
  local field="$1"
  local release_json="$2"

  jq -r --arg field "$field" '.[$field] // empty' <<<"$release_json"
}

resolve_from_release_json() {
  local release_json="$1"
  local field_value normalized_version version_token

  # Release titles carry the canonical app version; tags can include GitHub-only recovery suffixes.
  field_value="$(json_field name "$release_json")"
  if version_token="$(extract_version_token "$field_value")" \
    && normalized_version="$(normalize_target_version "$version_token")"; then
    printf '%s\n' "$normalized_version"
    return 0
  fi

  field_value="$(json_field tag_name "$release_json")"
  if version_token="$(extract_version_token "$field_value")" \
    && normalized_version="$(normalize_target_version "$version_token")"; then
    printf '%s\n' "$normalized_version"
    return 0
  fi

  return 1
}

target_input="${INPUT_VERSION:-}"
if [ -n "$target_input" ]; then
  if ! target_version="$(normalize_target_version "$target_input")"; then
    echo "Invalid target version: $target_input"
    echo "Expected a stable OpenClaw version like 2026.3.13"
    exit 1
  fi

  if [ "$target_input" != "$target_version" ]; then
    echo "Normalized target version: $target_input -> $target_version"
  fi
else
  release_json="${RELEASE_JSON:-}"
  if [ -z "$release_json" ]; then
    release_json="$(gh api repos/openclaw/openclaw/releases/latest)"
  fi

  if ! target_version="$(resolve_from_release_json "$release_json")"; then
    release_name="$(json_field name "$release_json")"
    release_tag="$(json_field tag_name "$release_json")"
    echo "Invalid target version from latest release: name='${release_name:-<empty>}' tag='${release_tag:-<empty>}'"
    exit 1
  fi
fi

echo "version=$target_version" >> "$GITHUB_OUTPUT"
echo "Target OpenClaw version: $target_version"
