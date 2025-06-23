# Public methods

All public methods are available via the `kulala` module.

### run

`require('kulala').run()` runs the current request.

### run_all

`require('kulala').run_all()` runs all requests in the current buffer.

### replay

`require('kulala').replay()` replays the last run request.

### open

`require('kulala').open()` opens default UI in default view

### inspect

`require('kulala').inspect()` inspects the current request.

It opens up a floating window with the parsed request.

### show_stats

`require('kulala').show_stats()` shows the statistics of the last run request.

### scratchpad

`require('kulala').scratchpad()` opens the scratchpad.

The scratchpad is a (throwaway) buffer where you can write your requests.

It's useful for quick testing.
It's useful for requests that you don't want to save.

It's default contents can be configured via the
[`scratchpad_default_contents`][scratchpad_default_contents]
configuration option.

### copy

`require('kulala').copy()` copies the current request
(as cURL command) to the clipboard.

### from_curl

`require('kulala').from_curl()` parse the cURL command from the clipboard and
write the HTTP spec into current buffer.
It's useful for importing requests from other tools like browsers.

### close

`require('kulala').close()` closes the kulala window and
also the current buffer.

> (it'll not close the current buffer, if it's not a `.http` or `.rest` file)

### toggle_view

`require('kulala').toggle_view()` toggles between
the `body` and `headers` view of the last run request.

### search

`require('kulala').search()` searches for all *named* requests in the current buffer.

:::tip

Named requests are those that have a name like so:

```http
### MY_REQUEST_NAME
GET http://example.com
```

:::


It tries to load up a telescope prompt to select a
file or fallback to using `vim.ui.select`.

### jump_prev

`require('kulala').jump_prev()` jumps to the previous request.

### jump_next

`require('kulala').jump_next()` jumps to the next request.

### scripts_clear_global

`require('kulala').scripts_clear_global('variable_name')`
clears a global variable set via
[`client.global.set`](../scripts/client-reference).

You can clear all globals by omitting the `variable_name` like so:
`require('kulala').scripts_clear_global()`.

Additionally, you can clear a list of global variables by
passing a table of variable names like so:
`require('kulala').scripts_clear_global({'variable_name1', 'variable_name2'})`.

### clear_cached_files

`require('kulala').clear_cached_files()`
clears all cached files.

These files include:

- last response body
- last response headers
- last response erorrs
- last request data
- global variables set via scripts
- compiled pre- and post-request scripts

### download_graphql_schema

You can download the schema of a GraphQL server with:

```
:lua require("kulala").download_graphql_schema()
```

You need to have your cursor on a line with a GraphQL request.

The file will be downloaded to
the directory where the current file is located.

The filename will be
`[request name].graphql-schema.json`.

This is required for the autocompletion and type checking to work.

### get_selected_env

:::warning

This function is only available if you are using a `http-client.env.json` file.

:::

`require('kulala').get_selected_env()`
returns the selected environment.

### set_selected_env

:::warning

This function is only available if you are using a `http-client.env.json` file.

:::

`require('kulala').set_selected_env(env_key)`
sets the selected environment.

See: [Environment Files][env-files].

If you omit the `env_key`,
it'll try to load up a telescope prompt to
select an environment or fallback to using `vim.ui.select`.

[scratchpad_default_contents]: ../getting-started/configuration-options#uiscratchpad_default_contents
[env-files]: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files

### generate_bug_report

`require('kulala').generate_bug_report()`
Generates a bug report and opens a GitHub issue with it.
