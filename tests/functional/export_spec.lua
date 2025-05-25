---@diagnostic disable: undefined-field, redefined-local

local export = require("kulala.cmd.export")
local h = require("test_helper")

local function sort(tbl, key)
  table.sort(tbl, function(a, b)
    return a[key or "id"] < b[key or "id"]
  end)
end

describe("export", function()
  local buf, result

  before_each(function()
    h.delete_all_bufs()
  end)

  after_each(function() end)

  it("#wip to Postman", function()
    buf = h.create_buf(
      ([[
        ### Request 1
        # Kulala Request Description 1

        < {%
          console.log("This is PRE request")
        %}

        # Kulala Request Description 2

        @var_name = var_value
        @var_name_2 = var_value_2

        POST https://httpbin.org/post HTTP/1.1
        Accept: application/json
        Content-Type: application/json

        {
          "results": [
            { "id": 1, "desc": "some_username" }
          ]
        }

        > {%
          console.log("This is POST request")
        %}

        ### Request 2

        GET https://httpbin.org/get?param1=value1&param2=value
        %}
      ]]):to_table(true),
      h.expand_path("fixtures/export.http"),
      false
    )

    -- vim.cmd("write!")

    local collection = export.export_requests() or {}

    local group = collection.item[1]
    local item = group.item[1]

    sort(item.event, "listen")
    sort(item.request.header, "key")
    sort(collection.variable)

    local file = vim.api.nvim_buf_get_name(buf)

    assert.has_properties(collection.info, {
      description = "Exported from Kulala: " .. file,
      name = "export",
      schema = "https://schema.getpostman.com/json/collection/v2.1.0/",
    })

    assert.has_properties(item, { id = 2, name = "Request 1" })

    assert.has_properties(item.event[1], {
      listen = "prerequest",
      script = {
        exec = 'console.log("This is PRE request")',
        type = "text/javascript",
      },
    })

    assert.has_properties(item.event[2], {
      listen = "test",
      script = { exec = 'console.log("This is POST request")', type = "text/javascript" },
    })

    assert.has_properties(item.request.header[1], {
      disabled = false,
      key = "Accept",
      value = "application/json",
    })

    assert.has_properties(item.request.header[2], {
      disabled = false,
      key = "Content-Type",
      value = "application/json",
    })

    assert.has_properties(item.request, {
      description = "Kulala Request Description 1\nKulala Request Description 2",
      method = "POST",
      url = "https://httpbin.org/post",
      body = {
        disabled = false,
        file = {},
        formdata = {},
        graphql = {},
        mode = "raw",
        options = {},
        raw = '{\n"results": [\n{ "id": 1, "desc": "some_username" }\n]\n}',
        urlencoded = {},
      },
    })

    assert.has_properties(collection.variable[1], {
      disabled = false,
      id = "var_name",
      key = "var_name",
      value = "var_value",
    })

    assert.has_properties(collection.variable[2], {
      disabled = false,
      id = "var_name_2",
      key = "var_name_2",
      value = "var_value_2",
    })

    item = group.item[2]
    assert.has_properties(item, {
      id = 28,
      name = "Request 2",
      request = { method = "GET", url = "https://httpbin.org/get?param1=value1&param2=value" },
    })
  end)
end)
