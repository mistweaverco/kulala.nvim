#!/usr/bin/env bash

set -eo pipefail

sudo apt update && \
  sudo apt install -y \
    curl \
    luacheck \
    neovim \
    stylua \
    vale
