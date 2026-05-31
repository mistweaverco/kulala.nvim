#!/usr/bin/env bash

set -eo pipefail

sudo apt-get update && \
  sudo apt-get install -y \
    curl \
    liblua5.3-dev \
    lua5.3 \
    luarocks

sudo luarocks install luacheck

curl --proto '=https' --tlsv1.2 -sSf https://rustup.rs | sh
cargo install stylua --features luajit --features lua52 --features lua53 --features lua54

sudo snap install vale
