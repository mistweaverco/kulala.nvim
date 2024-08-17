# DotEnv and HTTP client environment variables support

Kulala supports environment variables in `.http` files.

It allows you to define environment variables in a `.env` file or
in a `http-client.env.json` file (preferred) and reference them in your HTTP requests.

If you define the same environment variable in both the `.env` and the `http-client.env.json` file,
the value from the `http-client.env.json` file will be used.

The order of the environment variables resolution is as follows:

1. System environment variables
2. `http-client.env.json` file
3. `.env` file

:::note

The usage of environment variables is optional,
but if you want to use them,
we would advise you to use the `http-client.env.json` file.

DotEnv is still supported, but it is not recommended,
because it is not as flexible as the `http-client.env.json` file.

:::

### http-client.env.json

You can also define environment variables via the `http-client.env.json` file.

Create a file `http-client.env.json` in the root of your `.http` files directory and
define environment variables in it.

```json title="http-client.env.json"
{
  "dev": {
    "API_KEY": "your-api-key"
  },
  "testing": {
    "API_KEY": "your-api-key"
  },
  "staging": {
    "API_KEY": "your-api-key"
  },
  "prod": {
    "API_KEY": "your-api-key"
  }
}
```

The keys like `dev`, `testing`, `staging`, and `prod` are the environment names.

They can be used to switch between different environments.

You can freely define your own environment names.

By default the `dev` environment is used.

This can be overridden by [setting the `default_env` configuration option](../getting-started/configuration-options).

To change the environment, you can use the `:lua require('kulala').set_selected_env('prod')` command.

:::tip

You can also use the `:lua require('kulala').set_selected_env()`
command to select an environment using a telescope prompt.

:::

Then, you can reference the environment variables in your HTTP requests like this:

```http title="examples.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Authorization: Bearer {{API_KEY}}

{
  "name": "John"
}
```

#### Default http headers

You can define default HTTP headers in the `http-client.env.json` file.

You need to put them in the special `_base` key and
the `DEFAULT_HEADERS` will be merged with the headers from the HTTP requests.

```json title="http-client.env.json"
{
  "_base": {
    "DEFAULT_HEADERS": {
      "Content-Type": "application/json",
      "Accept": "application/json"
  },
  "dev": {
    "API_KEY": "your-api-key"
  }
}
```

Then, they are automatically added to the HTTP requests,
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
API_KEY=your-api-key
```

Then, you can reference the environment variables in your HTTP requests like this:

```http title="examples.http"
POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json
Authorization: Bearer {{API_KEY}}

{
  "name": "John"
}
```

