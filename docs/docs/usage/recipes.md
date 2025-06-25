# Recipes

This section provides various recipes for some common tasks

### Request confirmation when `sending all requests`

```lua
{
  opts = {
    global_keymaps = {
      ["Send all requests"] = {
        "<leader>Ra",
        function()
          vim.ui.input({ prompt = "Send all requests? (y/n)" }, function(input)
            if input == "y" then require("kulala").run_all() end
          end)
        end,
        mode = { "n", "v" },
      },
    },
  }
}
```

### Uploading a file

```http
@filename = logo.png
@filepath = ../../assets/badge-discord.svg
@content_type = image/jpeg

POST https://httpbin.org/post HTTP/1.1
Content-Type: multipart/form-data; boundary=----WebKitFormBoundary{{$timestamp}}

------WebKitFormBoundary{{$timestamp}}
Content-Disposition: form-data; name="file"; filename="{{filename}}"
Content-Type: {{content_type}}

< {{filepath}}

------WebKitFormBoundary{{$timestamp}}--
```

### Authenticating with browser-based auth

```http

### Acquire_XSRF_TOKEN

GET localhost:8000/login

> {%
  -- lua
  client.global.token = response.cookies["XSRF-TOKEN"].value
  client.global.decoded_token = vim.uri_decode(client.global.token)
  client.global.session = response.cookies["laravel_session"].value
%}

### Authentication

POST localhost:8000/login
Content-Type: application/json
X-Xsrf-Token: {{decoded_token}}
Cookie: XSRF-TOKEN={{token}}
Cookie: laravel_session={{session}}
Referer: http://localhost:8000/login

{
  "email": "mail@mail.com",
  "password": "passpass"
}

> {%
  -- lua
  -- save the new set authenticated session
  client.global.session = response.cookies["laravel_session"].value
%}

### Dashboard

run #Acquire_XSRF_TOKEN
run #Authentication

GET http://localhost:8000/dashboard
Cookie: laravel_session={{session}}
```
