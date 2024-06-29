#!/usr/bin/env bash

set -euo pipefail

GH_TAG="v$VERSION"

set_version() {
  ./scripts/set-version.sh
}

check_git_dirty() {
  if [[ -n $(git status -s) ]]; then
    echo "Working directory is dirty. Please commit or stash your changes before releasing."
    exit 1
  fi
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
