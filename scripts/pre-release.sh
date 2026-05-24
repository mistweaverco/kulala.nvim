#!/usr/bin/env bash

set -euo pipefail

GH_TAG="v$VERSION"

set_version() {
  ./scripts/set-version.sh
}

do_gh_release() {
  echo "Creating new pre-release $GH_TAG"
  gh release create --generate-notes "$GH_TAG" --latest=false
}

boot() {
  set_version
  do_gh_release
}

boot
