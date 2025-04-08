FROM ubuntu:latest

RUN apt-get update && apt-get upgrade -y && apt-get install -y curl git gcc lua5.1 luarocks unzip xclip pandoc
RUN mkdir -p _neovim && curl -sL https://github.com/neovim/neovim/releases/download/v0.11.0/nvim-linux-x86_64.tar.gz | tar -xz -C _neovim && mv _neovim/nvim-linux-x86_64 /usr/local/nvim && rm -rf _neovim
RUN mkdir -p _stylua && curl -sL https://github.com/JohnnyMorganz/StyLua/releases/download/v2.0.2/stylua-linux-x86_64.zip | funzip > _stylua/stylua && chmod +x _stylua/stylua && mv _stylua/stylua /usr/local/bin/stylua && rm -rf _stylua
RUN mkdir -p _vale && curl -sL https://github.com/errata-ai/vale/releases/download/v3.11.2/vale_3.11.2_Linux_64-bit.tar.gz | tar -xz -C _vale && mv _vale/vale /usr/local/bin/vale && rm -rf _vale
RUN luarocks install busted
RUN ln -s /usr/local/nvim/bin/nvim /usr/bin/nvim
RUN ln -s /usr/local/bin/stylua /usr/bin/stylua
RUN ln -s /usr/local/bin/vale /usr/bin/vale

# for xclip and neovim to work, see :h clipboard in neovim
ENV DISPLAY=:0

WORKDIR /app
