#!/usr/bin/env bash

set -eo pipefail

sudo apt update && \
  sudo apt install lua5.3 luarocks curl -y


sudo luarocks install luacheck

curl --proto '=https' --tlsv1.2 -sSf https://rustup.rs | sh
cargo install stylua --features luajit --features lua52 --features lua53 --features lua54

sudo snap install vale
