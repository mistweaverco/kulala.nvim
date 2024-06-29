#!/usr/bin/env bash

set -euo pipefail

update_lua_globals_version() {
  local tmp
  tmp=$(mktemp)
  sed -e "s/VERSION = \".*\"/VERSION = \"$VERSION\"/" ./lua/kulala/globals/init.lua > "$tmp" && mv "$tmp" ./lua/kulala/globals/init.lua
}

update_package_json_version() {
  local tmp
  tmp=$(mktemp)
  jq --arg v "$VERSION" '.version = $v' package.json > "$tmp" && mv "$tmp" package.json
}

update_docsify_version() {
  local tmp
  tmp=$(mktemp)
  sed -e "s/<small>.*<\/small>/<small>$VERSION<\/small>/" docs/_coverpage.md > "$tmp" && mv "$tmp" docs/_coverpage.md
}

update_lua_globals_version
update_package_json_version
update_docsify_version
