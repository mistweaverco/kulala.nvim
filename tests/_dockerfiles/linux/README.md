# Kulala Neovim Linux Testrunner Docker Image

This is a docker image for running tests in a Linux environment.

It is based on the [ubuntu](https://hub.docker.com/_/ubuntu) image.

## Features

- `neovim` v0.10.2
- `stylua` v0.20.0
- `vale` v2.28.0
- `curl`
- `git`
- `gcc`
- `lua5.1`
- `luarocks`
- `unzip`
- `xclip` (for neovim clipboard support)
- `luarocks busted` (for running tests)

## Building the image

```bash
make docker-build OS=linux
```

## Pushing the image

> [!WARNING]
> You need to have write access to the docker registry at
> `gorillamoe/kulala-nvim-linux-testrunner`.

```bash
make docker-push OS=linux
```
