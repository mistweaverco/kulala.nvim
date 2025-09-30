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

### Updating variables in http-profile.env.json from scripts

```http
POST http://httpbin.org/post HTTP/1.1
Content-Type: application/json

> {%
  -- lua
  local fs = require("kulala.utils.fs")
  local vars = fs.read_json("http-client.env.json") -- absolute path or relative to current buffer
  
  vars.dev.my_var = "hello world"
  fs.write_json("http-client.env.json", vars, true) -- absolute path or relative to current buffer
  
  client.log(vars)
%}

> {%
  const fs = require("fs");
  const json = fs.readFileSync("http-client.env.json", "utf8");
  const vars = JSON.parse(json);
  
  vars.dev.my_var = "hello my world";
  
  const jsonString = JSON.stringify(vars, null, 2);
  fs.writeFileSync("http-client.env.json", jsonString, "utf8");
  
  console.log(vars);
%}
```

### Changing JSON body of a request

```http
### Change JSON body

< {%
  -- lua
  local json = require("kulala.utils.json")
  local body = json.parse(request.body)

  body.your_var = "whatever"
  request.body_raw = json.encode(body)
%}

POST http://httpbin.org/post HTTP/1.1

{
  "your_var": "original_value"
}
```

### Iterating over results and making requests for each item

```http
### Request_one

POST https://httpbin.org/post HTTP/1.1
Accept: application/json
Content-Type: application/json

{
  "results": [
    { "id": 1, "desc": "some_username" },
    { "id": 2, "desc": "another_username" }
  ]
}

### Request_two

< {%
  -- lua
  local response = client.responses["Request_one"].json -- get body of the response decoded as json
  if not response then return end

  local item = response.json.results[request.iteration()]
  if not item then return request.skip() end   -- skip if no more items

  client.log(item)
  request.url_raw = request.environment.url .. "?" .. item.desc
%}

@url = https://httpbin.org/get
GET {{url}}

> {%
  -- lua
  request.replay()
%}
```
