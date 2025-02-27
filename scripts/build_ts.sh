#!/usr/bin/env bash

cp -r /home/yaro/projects/kulala.nvim/lua/kulala/parser/scripts/engines/javascript/lib/. /home/yaro/.cache/nvim/kulala/scripts/build/
npm run build --prefix /home/yaro/.cache/nvim/kulala/scripts/build/
