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
  set_version
  check_git_dirty
  do_gh_release
}

boot
