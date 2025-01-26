# Kulala Neovim Windows Testrunner Docker Image

This is a docker image for running tests in a Windows environment.

It is based on the [microsoft/windows-nanoserver](https://hub.docker.com/r/microsoft/windows-nanoserver) image.

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
- `luarocks busted` (for running tests)

## Building the image

> [!WARNING]
> You need to run the docker build command on
> a windows machine.
> It's a limitation of the windows docker images,
> provided by Microsoft, not us.

```bash
make docker-build OS=windows
```

## Pushing the image

> [!WARNING]
> You need to have write access to the docker registry at
> `gorillamoe/kulala-nvim-windows-testrunner`.

```bash
make docker-push OS=windows
```
