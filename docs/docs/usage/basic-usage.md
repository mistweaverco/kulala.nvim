# Basic Usage

## Basic usage summary (with default keymaps)

### Execute request

There are several ways to execute a request:

- Position the cursor on the line of the request or in the block of the request delimited by `###` and then press `<CR>` or `<leader>Rs` to run the request.
- Select several requests in visual mode and press `<CR>` or `<leader>Ra` to run the requests.
- Press `<leader>Ra` to run all requests in the buffer.
- You can use `#` to comment out a request or its data, and it'll not be processed.

### Executing requests in non `.http` files

- You can execute requests in any file type. However, since the `###` delimiters are only recognized in `.http` files, you will need to position the cursor exactly on the line with the request or visually select the required requests and their accompanying data.
- Common comment syntax is recognized, so you can run requests that are commented out in your code, for example:

```lua
vim.system("curl -X GET http://localhost:3000")

-- POST http://localhost:3000
-- Content-Type: application/json
-- {"name": "John Doe"}

```

### Kulala UI

![Kulala UI](./../../static/img/kulala_ui.png)

- Kulala UI is opened automatically when you run a request or you can open it manually with `<leader>Ro` at any time.
- You can switch between different views with `(H) Headers`, `B (Body)`, `(A) All`, `(V) Verbose`, `(S) Stats`, `(O) Script output`, `(R) Report`
- To scroll through the history of responses use `[` and `]`.
- To clear responses history press `X`.
- To jump to the request in the request buffer press `<CR>`.
- To open help window press `?`.
- To open the Kulala scratch buffer use `<leader>Rb`.

### Syntax summary

- `#` is used to comment out a request or its data.
- `###` is used to delimit requests and their data.

#### Metadata

- `# @meta-name meta-value` is used to add arbitrary metadata to a request or file.
- `# @name request-name` is used to name a request, so it can be referred to in scripts.
- `# @prompt variable-name prompt-string` is used to prompt the user for input and store it in a variable.

#### Directives

- `# @graphql` allows you to run a GraphQL query.
- `# @accept chunked` allows you to accept Transfer-Encoding: chunked responses and streamed responses.
- `# @grpc-global-...` and `# @grpc-...` allows you to set global and per-request flags for gRPC requests.

#### Variables

- `@variable-name=variable-value` is used to define variables that can be used in request URL, headers and body.
- `{{variable}}` allows you to use variables defined in `metadata`, `system environment` variables, `http-client.env.json` file or `.env` file.
- `{{$dynamic-variable}}` allows you to use predefined dynamic, aka `magic` variables.

#### Requests import

- `import /path/to/file` allows you to import requests from another file.
- `run #request-name` allows you to run a named request.
- `run /path/to/file` allows you to run all requests in another file.

#### File input/output

- `< /path/to/file` allows you to include the contents of a file in the request.
- `>> /path/to/file` allows you to save the response to a file. Use `>>!` to overwrite the file if it exists.

#### Scripts

- `> {% %}` allows you to run an inline `pre-request` `js` script.
- `> /path/to/script.js` allows you to run a `pre-request` `js` script in a file.
- `< {% %}` allows you to run an inline `post-request` `js` script.
- `< /path/to/script.js` allows you to run a `post-request` `js` script in a file.

For details please consult the corresponding sections in the documentation.
