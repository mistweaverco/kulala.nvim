# DotEnv and HTTP client environment variables support

Kulala supports environment variables in `.http` files.

It allows you to define environment variables in a `.env` file or
in a `http-client.env.json` file (preferred) and
reference them in your HTTP requests.

If you define the same environment variable in
both the `.env` and the `http-client.env.json` file,
the value from the `http-client.env.json` file will be used.

The order of the environment variables resolution is as follows:

1. System environment variables
2. `http-client.env.json` file
3. `.env` file

:::note

The usage of environment variables is optional,
but if you want to use them,
we would advise you to use the `http-client.env.json` file.

DotEnv is still supported, but it's not recommended,
because it's not as flexible as the `http-client.env.json` file.

:::

### http-client.env.json

You can also define environment variables via the `http-client.env.json` file.

Kulala will search for these files in parent directories starting from the working directory of the buffer and 
will merge them together, with the closest file taking precedence.

Press `<leader>Re` to open Environment Manager to select the environment and to open the corresponding file.

```json title="http-client.env.json"
{
  "$schema": "https://raw.githubusercontent.com/mistweaverco/kulala.nvim/main/schemas/http-client.env.schema.json",
  "dev": {
    "API_URL": "https://httpbin.org/post?env=dev",
    "API_KEY": ""
  },
  "testing": {
    "API_URL": "https://httpbin.org/post?env=testing",
    "API_KEY": ""
  },
  "staging": {
    "API_URL": "https://httpbin.org/post?env=staging",
    "API_KEY": ""
  },
  "prod": {
    "API_URL": "https://httpbin.org/post?env=prod",
    "API_KEY": ""
  }
}
```

The keys like `dev`, `testing`, `staging`, and `prod` are the environment names.

They can be used to switch between different environments.

You can freely define your own environment names.

By default the `dev` environment is used.

This can be overridden by
[setting the `default_env` configuration option][config].

To change the environment,
you can use the `:lua require('kulala').set_selected_env('prod')` command.

:::tip

You can also use the `:lua require('kulala').set_selected_env()`
command to select an environment using a telescope prompt.

:::

As you can see in the example above,
we defined the `API_URL` and `API_KEY` environment variables,
but left the `API_KEY` empty.

This is by intention, because we can define the `API_KEY` in the
`http-client.private.env.json` file.

:::danger

You should never commit sensitive data like API keys to your repository.
So always use the `http-client.private.env.json` file for that and
add it to your `.gitignore` file.

:::

```json title="http-client.private.env.json"
{
  "$schema": "https://raw.githubusercontent.com/mistweaverco/kulala.nvim/main/schemas/http-client.private.env.schema.json",
  "dev": {
    "API_KEY": "d3v"
  },
  "testing": {
    "API_KEY": "t3st1ng"
  },
  "staging": {
    "API_KEY": "st4g1ng"
  },
  "prod": {
    "API_KEY": "pr0d"
  }
}
```

Then, you can reference the environment variables
in your HTTP requests like this:

```http title="examples.http"
POST {{API_URL}} HTTP/1.1
Content-Type: application/json
Authorization: Bearer {{API_KEY}}

{
  "name": "John"
}
```

#### Default http headers

You can define default HTTP headers in the `http-client.env.json` file.

They can be put per environment or in `$shared` property to be shared by all environments. 
The `$default_headers` will be merged with the headers from the HTTP requests.

You can also define a special header `Host`, which will set the default host for all your requests.

```json title="http-client.env.json"
{
  "$schema": "https://raw.githubusercontent.com/mistweaverco/kulala.nvim/main/schemas/http-client.env.schema.json",
  "$shared": {
    "$default_headers": {
      "Content-Type": "application/json",
      "Accept": "application/json"
    },
  },
  "dev": {
    "API_URL": "https://httpbin.org/post?env=dev",
    "API_KEY": ""
  }
}
```

Then, they're automatically added to the HTTP requests,
unless you override them.

```http title="examples.http"
POST https://httpbin.org/post HTTP/1.1
Authorization: Bearer {{API_KEY}}

{
  "name": "John"
}
```

### DotEnv

You can create a `.env` file in the root of your `.http` files directory and
define environment variables in it.

The file should look like this:

```env title=".env"
API_URL=https://httpbin.org/post
API_KEY=your-api-key
```

Then, you can reference the environment variables
in your HTTP requests like this:

```http title="examples.http"
POST {{API_URL}} HTTP/1.1
Content-Type: application/json
Authorization: Bearer {{API_KEY}}

{
  "name": "John"
}
```
