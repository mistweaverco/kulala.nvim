#!/usr/bin/env bash

# Fetch latest version from git tags and strip the leading 'v' if present
VERSION=${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}
CHANGELOG_FILE="CHANGELOG.md"
TEMP_CONFIG=$(mktemp --suffix=".json")
echo "{\"version\": \"$VERSION\", \"date\": \"$(date +%Y-%m-%d)\"}" > "$TEMP_CONFIG"

echo "Generating changelog for version: ${VERSION}"
echo "Using PKG_VERSION: ${PKG_VERSION}"

should_workaround_detached_head=""
if [[ -n "$CI" ]]; then
  should_workaround_detached_head="1"
elif [[ "$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" == "HEAD" ]]; then
  # Local reproduction of CI behavior: detached HEAD (often at a tag).
  # conventional-changelog can treat the current tag as "unreleased" and
  # only emit notes up to the previous tag unless we temporarily remove it.
  should_workaround_detached_head="1"
fi

tag_name="v$VERSION"
tag_target=""
tag_was_deleted=""
if [[ -n "$should_workaround_detached_head" ]]; then
  if git rev-parse "$tag_name" >/dev/null 2>&1; then
    tag_target="$(git rev-list -n 1 "$tag_name" 2>/dev/null || true)"
    git tag -d "$tag_name" 2>/dev/null && tag_was_deleted="1"
  fi
fi

./node_modules/.bin/conventional-changelog \
  -i "$CHANGELOG_FILE" \
  -s \
  -r 0 \
  -u \
  -k "$TEMP_CONFIG" \
  -c "$TEMP_CONFIG"

rm "$TEMP_CONFIG"

if [[ -n "$tag_was_deleted" ]]; then
  # Restore the tag to its original target (do not retag HEAD).
  if [[ -n "$tag_target" ]]; then
    git tag "$tag_name" "$tag_target" 2>/dev/null || true
  else
    git tag "$tag_name" 2>/dev/null || true
  fi
fi

if [[ ! -f "${CHANGELOG_FILE}" ]]; then
  echo "ERROR: ${CHANGELOG_FILE} not found"
  exit 1
fi
