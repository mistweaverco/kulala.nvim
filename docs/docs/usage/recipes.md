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
