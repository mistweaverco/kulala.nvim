# Public methods

All public methods are available via the `kulala` module.

### run

`require('kulala').run()` runs the current request.

### run_all

`require('kulala').run_all()` runs all requests in the current buffer.

### replay

`require('kulala').replay()` replays the last run request.

### inspect

`require('kulala').inspect()` inspects the current request.

It opens up a floating window with the parsed request.

### show_stats

`require('kulala').show_stats()` shows the statistics of the last run request.

### scratchpad

`require('kulala').scratchpad()` opens the scratchpad.

The scratchpad is a (throwaway) buffer where you can write your requests.

It is useful for quick testing. It is useful for requests that you don't want to save.

It's default contents can be configured via the
[`scratchpad_default_contents`][scratchpad_default_contents] configuration option.

### copy

`require('kulala').copy()` copies the current request
(as cURL command) to the clipboard.

### from_curl

`require('kulala').from_curl()` parse the cURL command from the clipboard and
write the HTTP spec into current buffer. It is useful for importing requests
from other tools like browsers.

### close

`require('kulala').close()` closes the kulala window and also the current buffer.

> (it will not close the current buffer, if it is not a `.http` or `.rest` file)

### toggle_view

`require('kulala').toggle_view()` toggles between
the `body` and `headers` view of the last run request.

Persists across restarts.

### toggle_virtual_variable

`require('kulala').toggle_virtual_variable()` toggles between
the `variable` and `virtual text`.

### search

`require('kulala').search()` searches for all `.http` and `.rest` files
in the current working directory.

It tries to load up a telescope prompt to select a file or fallback to using `vim.ui.select`.

### jump_prev

`require('kulala').jump_prev()` jumps to the previous request.

### jump_next

`require('kulala').jump_next()` jumps to the next request.

### scripts_clear_global

`require('kulala').scripts_clear_global('variable_name')`
clears a global variable set via [`client.global.set`](../scripts/client-reference).

You can clear all globals by omitting the `variable_name` like so:
`require('kulala').scripts_clear_global()`.

Additionally, you can clear a list of global variables by
passing a table of variable names like so:
`require('kulala').scripts_clear_global({'variable_name1', 'variable_name2'})`.

### download_graphql_schema

You can download the schema of a GraphQL server with:

```
:lua require("kulala").download_graphql_schema()
```

You need to have your cursor on a line with a GraphQL request.

The file will be downloaded to the the directory where the current file is located.

The filename will be `[http-file-name-without-extension].graphql-schema.json`.

This file can be used in conjunction with
the [kulala-cmp-graphql][kulala-cmp-graphql] plugin to
provide autocompletion and type checking.

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

See: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files

If you omit the `env_key`,
it will try to load up a telescope prompt to select an environment or fallback to using `vim.ui.select`.

[scratchpad_default_contents]: ../getting-started/configuration-options#scratchpad_default_contents
[kulala-cmp-graphql]: https://github.com/mistweaverco/kulala-cmp-graphql.nvim
