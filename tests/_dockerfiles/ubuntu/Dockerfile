FROM ubuntu:latest

RUN apt-get update && apt-get upgrade -y && apt-get install -y curl git gcc lua5.1 luarocks
RUN mkdir -p _neovim && curl -sL https://github.com/neovim/neovim/releases/download/v0.10.1/nvim-linux64.tar.gz | tar -xz -C _neovim && mv _neovim/nvim-linux64 /usr/local/nvim && rm -rf _neovim
RUN luarocks install busted
RUN ln -s /usr/local/nvim/bin/nvim /usr/bin/nvim
