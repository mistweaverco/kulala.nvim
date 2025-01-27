# API

Kulala currently provides one event to hook into,
but more are planned for the future.

## after_next_request

Triggered after the next request has been successfully completed.
The queue of callbacks resets after this event is triggered.

```lua
require('kulala.api').on("after_next_request", function(data)
  print("Request completed")
  print("Headers: " .. data.headers)
  print("Body: " .. data.body)
end)
```

## after_request

Triggered after a request has been successfully completed.

```lua
require('kulala.api').on("after_request", function(data)
  print("Request completed")
  print("Headers: " .. data.headers)
  print("Body: " .. data.body)
end)
```
