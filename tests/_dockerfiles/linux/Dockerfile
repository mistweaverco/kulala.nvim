FROM ubuntu:24.04

ENV DISPLAY=:0 \
    PATH="/usr/local/nvim/bin:${PATH}"

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    gcc \
    lua5.1 \
    luarocks \
    unzip \
    xclip \
    pandoc \
    jq \
    libxml2-utils \
    gh \
    ca-certificates \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g prettier \
    && luarocks install busted \
    && curl -sL https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-x86_64.tar.gz | tar -xz -C /tmp \
    && mv /tmp/nvim-linux-x86_64 /usr/local/nvim \
    && curl -sL https://github.com/JohnnyMorganz/StyLua/releases/download/v2.0.2/stylua-linux-x86_64.zip | funzip > /usr/local/bin/stylua \
    && chmod +x /usr/local/bin/stylua \
    && curl -sL https://github.com/errata-ai/vale/releases/download/v3.11.2/vale_3.11.2_Linux_64-bit.tar.gz | tar -xz -C /tmp \
    && mv /tmp/vale /usr/local/bin/vale \
    && curl -sL https://github.com/tree-sitter/tree-sitter/releases/download/v0.24.6/tree-sitter-linux-x64.gz | gunzip > /usr/local/bin/tree-sitter \
    && chmod +x /usr/local/bin/tree-sitter \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

WORKDIR /app
