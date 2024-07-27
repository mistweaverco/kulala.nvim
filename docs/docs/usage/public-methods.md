# Public methods

All public methods are available via the `kulala` module.

### run

`require('kulala').run()` runs the current request.

### copy

`require('kulala').copy()` copies the current request
(as cURL command) to the clipboard.

### close

`require('kulala').close()` closes the kulala window and also the current buffer.

> (it will not close the current buffer, if it is not a `.http` or `.rest` file)

### toggle_view

`require('kulala').toggle_view()` toggles between
the `body` and `headers` view of the last run request.

Persists across restarts.

### jump_prev

`require('kulala').jump_prev()` jumps to the previous request.

### jump_next

`require('kulala').jump_next()` jumps to the next request.

### set_selected_env

> If you are using a dotenv (`.env`) file,
> this function has no effect.
>
> It is only for setting the selected environment of
> a `http-client.env.json` file.

`require('kulala').set_selected_env(env_key)`
sets the selected environment.

See: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files

If you omit the `env_key`,
it will try to load up a telescope prompt to select an environment or fallback to using `vim.ui.select`.
