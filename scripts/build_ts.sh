#!/usr/bin/env bash

cp -r lua/kulala/parser/scripts/engines/javascript/lib/. ${XDG_CACHE_HOME}/nvim/kulala/scripts/build/
npm run build --prefix ${XDG_CACHE_HOME}/nvim/kulala/scripts/build/

cp -r lua/kulala/parser/scripts/engines/javascript/lib/. .tests/cache/nvim/kulala/scripts/build/
npm run build --prefix .tests/cache/nvim/kulala/scripts/build/
