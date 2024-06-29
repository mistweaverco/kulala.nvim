#!/usr/bin/env bash

set -euo pipefail

GH_TAG="v$VERSION"

set_version() {
  ./scripts/set-version.sh
}

do_gh_release() {
  echo "Creating new release $GH_TAG"
  gh release create --generate-notes "$GH_TAG"
}

boot() {
  update_lua_globals_version
  update_package_json_version
  update_docsify_version
  check_git_dirty
  do_gh_release
}

boot
