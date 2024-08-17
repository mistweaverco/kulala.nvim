# API

Kulala currently provides one event to hook into,
but more are planned for the future.

## after_request

Triggered after a request has been successfully completed.

```lua
require('kulala.api').on("after_request", function(data)
  print("Request completed")
  print("Headers: " .. data.headers)
  print("Body: " .. data.body)
end)
```
