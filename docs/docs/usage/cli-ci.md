# CLI and CI

The Kulala CLI is a command-line interface that allows you to execute HTTP files from the command line. 

It can be used standalone or as part of a CI/CD pipeline, effectively turning your HTTP files into an API test suite.

## Installation and Requirements

Kulala CLI is basically a CLI interface for Kulala, so it requires Neovim (nvim) and curl to be present on your PATH. 

You can install it either as you would usually install Kulala as a Neovim plugin, or you can manually clone the repository.

Optionally, grpcurl (for GRPC), websocat (for Websockets), jq (for JSON formatting) and nvim-treesitter for response highlighting may be installed.

The CLI executable is `kulala.nvim/lua/cli/kulala_cli.lua` file, which you can put on your PATH.

## Configuration

The CLI comes with some sane defaults, but you can override them in `kulala.nvim/lua/cli/config.lua`.

## Kulala CLI

```text
Usage: 

      Kulala CLI [--list] [--halt] [-m] [-h] 

      [-v {body,headers,headers_body,verbose,script_output,report}]

      [-e <env>] [-n <name> ...] [-l <line> ...]

      [<input>] ...

Commands:
      import [<path>]            Import HTTP collection from Postman/OpenAPI/Bruno
      export [<path>]            Export HTTP file or folder to Postman collection

Arguments:

      input                      Path to folder or HTTP file/s
                            
Options:                    

      --list                     List requests in HTTP file
                                
      --name (-n) [<name>] ...   Filter requests by name
                                
      --line (-l) [<line>] ...   Filter requests by line #
                                
      --env (-e) <env>           Environment

      --sub (-s) <var=value> ... Substitute variable(s)
                                
      --view (-v)                Response view
                                  {body,headers,headers_body,verbose,script_output,report}
                                
      --halt                     Halt on error
                                
      --mono (-m)                No color output

      --from (-f)                Import from {postman, openapi, bruno}

      --help (-h)                Help
```

```bash
kulala_cli http_examples/cli.http -e prod -v report -n Login Request -l 15 20 
kulala_cli cli.http grpc.http --sub token=abcd1234 user=42
kulala_cli http_examples --list

kulala_cli import collection.json --from postman
kulala_cli export requests.http
```

:::info

`@prompt` and `@secret` are not supported in CLI mode and will be ignored.

The variable values must be provided via environment variables, environment files or supplied with --sub option.

:::

## Kulala CI

Kulala provides a GitHub Action to run HTTP files as part of your CI/CD pipeline.

The action is available at Github Marketplace: [Kulala Action](https://github.com/marketplace/actions/kulala-cli-action). 

Or at [Kulala GH Action](https://github.com/mistweaverco/kulala-github-action)

Example:
```yaml
---
name: main
on:
  pull_request: ~
jobs:
  build:
    name: Run HTTP tests
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Setup Kulala CI
        uses: mistweaverco/kulala-github-action@v1

      - name: Run Kulala CI
        run: |
          kulala_cli.lua http/cli.http
          kulala_cli.lua http -v report
        shell: bash
        env:
          COLUMNS: 120
```
