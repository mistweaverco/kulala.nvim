#!/usr/bin/env bash

set -eo pipefail

NEOVIM_VERSION=${NEOVIM_VERSION:-"0.12.2"}

sudo apt-get update
sudo apt-get install -y curl liblua5.3-dev lua5.3 luarocks

# Install Neovim
curl -LO "https://github.com/neovim/neovim/releases/download/v$NEOVIM_VERSION/nvim-linux-x86_64.tar.gz"
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
echo "/opt/nvim-linux-x86_64/bin" >> "$GITHUB_PATH"

sudo luarocks install luacheck

sudo npm install -g @johnnymorganz/stylua-bin
sudo npm install -g tree-sitter-cli

sudo snap install vale
