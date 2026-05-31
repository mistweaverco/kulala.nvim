#!/usr/bin/env bash

set -eo pipefail

sudo apt-get update
sudo apt-get install -y curl liblua5.3-dev lua5.3 luarocks neovim

sudo luarocks install luacheck

sudo npm install -g @johnnymorganz/stylua-bin

sudo snap install vale
