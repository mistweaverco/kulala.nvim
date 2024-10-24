#!/usr/bin/env bash

# Creates a tag based on the version found in lua/kulala/globals.lua
# and pushes it to the remote repository.

set -euo pipefail

get_tag() {
  local file="./lua/kulala/globals/init.lua"
  local VERSION_REGEX="VERSION = \"([0-9]+\.[0-9]+\.[0-9]+)\""
  local version
  version=$(grep -oP "$VERSION_REGEX" "$file" | cut -d'"' -f2)
  echo "v$version"
}

check_on_main_branch() {
  local branch
  branch=$(git branch --show-current)
  if [ "$branch" != "main" ]; then
    echo "You must be on the main branch to create a tag."
    exit 1
  fi
}

check_if_clean() {
  if ! git diff --quiet; then
    echo "You have uncommitted changes. Please commit or stash them before creating a tag."
    exit 1
  fi
}

check_on_main_branch
check_if_clean

tag=$(get_tag)

git tag "$tag" && git push origin "$tag"
