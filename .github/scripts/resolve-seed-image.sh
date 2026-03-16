#!/usr/bin/env bash
set -euo pipefail

: "${TARGET_VERSION:?TARGET_VERSION is required}"

emit_output() {
  local key="$1"
  local value="$2"
  echo "$key=$value" >> "$GITHUB_OUTPUT"
}

seed_repo="${INPUT_SEED_IMAGE_REPO:-ghcr.io/weak-fox/openclaw-offline-seed}"
seed_semver="${INPUT_SEED_SEMVER:-}"
seed_tag=""
seed_image=""
exists="false"
reason=""

if [ -n "$seed_semver" ]; then
  seed_tag="v${seed_semver}-oc-${TARGET_VERSION}"
else
  releases_json="${SEED_RELEASES_JSON:-}"
  if [ -z "$releases_json" ]; then
    releases_json="$(gh api repos/weak-fox/openclaw-offline-seed/releases)"
  fi

  seed_tag="$(
    jq -r --arg target "$TARGET_VERSION" '
      map(select((.draft | not) and (.prerelease | not)))
      | map(.tag_name // "")
      | map(select(startswith("v") and endswith("-oc-" + $target)))
      | first // empty
    ' <<<"$releases_json"
  )"

  if [ -n "$seed_tag" ]; then
    seed_semver="${seed_tag#v}"
    seed_semver="${seed_semver%-oc-${TARGET_VERSION}}"
  else
    reason="No seed release found matching OpenClaw version: $TARGET_VERSION"
  fi
fi

if [ -n "$seed_tag" ]; then
  seed_image="${seed_repo}:${seed_tag}"
fi

if [ -n "$seed_image" ]; then
  if [ -n "${SEED_IMAGE_EXISTS:-}" ]; then
    exists="$SEED_IMAGE_EXISTS"
  elif docker manifest inspect "$seed_image" >/dev/null 2>&1; then
    exists="true"
  fi
fi

if [ "$exists" != "true" ] && [ -z "$reason" ] && [ -n "$seed_image" ]; then
  reason="Seed image missing: $seed_image"
fi

emit_output semver "$seed_semver"
emit_output repo "$seed_repo"
emit_output tag "$seed_tag"
emit_output image "$seed_image"
emit_output exists "$exists"
emit_output reason "$reason"

if [ "$exists" = "true" ]; then
  echo "Seed image exists: $seed_image"
elif [ -n "$reason" ]; then
  echo "$reason"
fi
