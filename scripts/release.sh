#!/usr/bin/env bash

set -euo pipefail

GH_TAG="v$VERSION"
PLUGIN_VERSION_FILE="./lua/kulala/globals/versions/plugin.lua"

check_version_matches_tag() {
  local v
  v=$(cat "$PLUGIN_VERSION_FILE" | grep 'return "' | sed 's/return "\(.*\)"/\1/')
  if [[ "$VERSION" != "$v" ]]; then
    echo "Found version $v in $PLUGIN_VERSION_FILE, but expected $VERSION."
    exit 1
  fi
}

do_gh_release() {
  echo "Creating new release $GH_TAG"
  gh release create --generate-notes "$GH_TAG"
}

boot() {
  check_version_matches_tag
  do_gh_release
}

boot
