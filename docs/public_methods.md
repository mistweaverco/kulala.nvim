## Public methods

### `require('kulala').run()`

Run the current request.

### `require('kulala').toggle_view()`

Toggles between the `body` and `headers` view of the last run request.

Persists across restarts.

### `require('kulala').jump_prev()`

Jump to the previous request.

### `require('kulala').jump_next()`

Jump to the next request.

### `require('kulala').set_selected_env(env_key)`

> If you are using a dotenv (`.env`) file,
> this function has no effect.
>
> It is only for setting the selected environment of
> a `http-client.env.json` file.

Set the selected environment.

See: https://learn.microsoft.com/en-us/aspnet/core/test/http-files?view=aspnetcore-8.0#environment-files

If you omit the `env_key`,
it will try to load up a telescope prompt to select an environment.
