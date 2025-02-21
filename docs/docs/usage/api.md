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
  print("Complete response: " .. data.response)
end)
```

## after_request

Triggered after a request has been successfully completed.

```lua
require('kulala.api').on("after_request", function(data)
  print("Request completed")
  print("Headers: " .. data.headers)
  print("Body: " .. data.body)
  print("Complete response: " .. data.response)
end)
```

Response data has the following fields:

```lua
---@class RequestData
---@field headers string
---@field body string
---@field response Response
data = {}

---@class Response
---@field id number
---@field url string
---@field method string
---@field status number
---@field duration number
---@field time string
---@field body string
---@field headers string
---@field errors string
---@field stats string
---@field script_pre_output string
---@field script_post_output string
---@field buf number
---@field buf_name string
---@field line number
response = {}
```
