#!/usr/bin/env bash

SCRIPT_DIR=lua/kulala/parser/scripts/engines/javascript/lib/.
KULALA_DIR=nvim/kulala/scripts/build

echo "Building in ${XDG_CACHE_HOME}/$KULALA_DIR"
cp -r $SCRIPT_DIR ${XDG_CACHE_HOME}/$KULALA_DIR
npm run build --prefix ${XDG_CACHE_HOME}/$KULALA_DIR

echo "Building in .tests/cache/$KULALA_DIR"
cp -r $SCRIPT_DIR .tests/cache/$KULALA_DIR
npm run build --prefix .tests/cache/$KULALA_DIR
