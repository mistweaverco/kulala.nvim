---@diagnostic disable: undefined-field, redefined-local

local Logger = require("kulala.logger")
local export = require("kulala.cmd.export")
local fs = require("kulala.utils.fs")
local h = require("test_helper")

local function sort(tbl, key)
  table.sort(tbl, function(a, b)
    return a[key or "id"] < b[key or "id"]
  end)
end

describe("export to Postman", function()
  before_each(function()
    h.delete_all_bufs()
    stub(fs, "write_json", true)
    stub(Logger, "info", true)
  end)

  after_each(function()
    fs.write_json:revert()
    Logger.info:revert()
  end)

  it("exports file", function()
    vim.cmd.edit(h.expand_path("fixtures/export/export_1.http"))

    local collection = export.export_requests() or {}

    local group = collection.item[1]
    local item = group.item[1]

    sort(item.event, "listen")
    sort(item.request.header, "key")
    sort(collection.variable)

    local file = vim.api.nvim_buf_get_name(0)

    assert.has_properties(collection.info, {
      description = "Exported from Kulala: " .. file,
      name = "export_1",
      schema = "https://schema.getpostman.com/json/collection/v2.1.0/",
    })

    assert.has_properties(item, { id = "export_1:2", name = "Request 1" })

    assert.has_properties(item.event[1], {
      listen = "prerequest",
      script = {
        exec = { '  console.log("This is PRE request")' },
        type = "text/javascript",
      },
    })

    assert.has_properties(item.event[2], {
      listen = "test",
      script = { exec = { '  console.log("This is POST request")' }, type = "text/javascript" },
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
      url = { raw = "https://httpbin.org/post" },
      body = {
        disabled = false,
        file = {},
        formdata = {},
        graphql = {},
        mode = "raw",
        options = {},
        raw = '{\n  "results": [\n    { "id": 1, "desc": "some_username" }\n  ]\n}',
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
      id = "export_1:28",
      name = "Request 2",
      request = { method = "GET", url = { raw = "https://httpbin.org/get?param1=value1&param2=value" } },
    })

    assert.has_properties(item.event[1], {
      listen = "test",
      script = {
        exec = 'console.log("POST script file");\n',
        type = "text/javascript",
      },
    })
  end)

  it("exports folder", function()
    local file = h.expand_path("fixtures/export/export_1.http")
    local folder = vim.fs.dirname(file)

    vim.cmd.edit(file)
    local collection = export.export_requests(folder) or {}

    local path = vim.fs.dirname(vim.api.nvim_buf_get_name(0))

    assert.has_properties(collection.info, {
      description = "Exported from Kulala: " .. vim.fs.dirname(file),
      name = "export",
      schema = "https://schema.getpostman.com/json/collection/v2.1.0/",
    })

    local group = collection.item[1]
    assert.has_properties(group, {
      name = "export_1",
      description = "Kulala Export: " .. path .. "/export_1.http",
    })

    assert.has_properties(group.item[1], {
      id = "export_1:2",
      name = "Request 1",
    })

    group = collection.item[2]
    assert.has_properties(group, {
      name = "export_2",
      description = "Kulala Export: " .. path .. "/export_2.http",
    })

    assert.has_properties(group.item[1], {
      id = "export_2:6",
      name = "Request 3",
    })

    assert.is_same(10, #collection.variable)
  end)

  it("parses url and params", function()
    vim.cmd.edit(h.expand_path("fixtures/export/export_1.http"))

    local collection = export.export_requests() or {}

    local group = collection.item[1]
    local item = group.item[3]

    sort(item.request.url.query, "key")

    assert.has_properties(item.request.url, {
      raw = "https://httpbin.org:443/get?param1=value1&param2=value#fragment",
      protocol = "https",
      host = "httpbin.org",
      path = "/get",
      port = "443",
      query = {
        { key = "param1", value = "value1" },
        { key = "param2", value = "value" },
      },
      hash = "fragment",
    })
  end)

  it("parses body with urlecoded params", function()
    vim.cmd.edit(h.expand_path("fixtures/export/export_1.http"))

    local collection = export.export_requests() or {}

    local group = collection.item[1]
    local item = group.item[4]

    assert.has_properties(item.request.url, {
      raw = "httpbin.org/post",
      protocol = "http",
    })

    sort(item.request.body.urlencoded, "key")

    assert.has_properties(item.request.body, {
      raw = "username=foo&password=bar&client_id=foo&colors[]=red&colors[]=blue&levels[0]=top&levels[1]=bottom&skill=jump&skill=run",
      mode = "urlencoded",

      urlencoded = {
        {
          disabled = false,
          key = "client_id",
          value = "foo",
        },
        {
          disabled = false,
          key = "colors",
          value = "red,blue",
        },
        {
          disabled = false,
          key = "levels",
          value = "top,bottom",
        },
        {
          disabled = false,
          key = "password",
          value = "bar",
        },
        {
          disabled = false,
          key = "skill",
          value = "jump,run",
        },
        {
          disabled = false,
          key = "username",
          value = "foo",
        },
      },
    })
  end)

  it("parses body with formdata", function()
    vim.cmd.edit(h.expand_path("fixtures/export/export_1.http"))

    local collection = export.export_requests() or {}

    local group = collection.item[1]
    local item = group.item[5]

    sort(item.request.body.formdata, "key")

    assert.has_properties(item.request.body, {
      mode = "formdata",
      formdata = {
        {
          contentType = "",
          disabled = false,
          key = "h",
          src = "",
          type = "text",
          value = "514.5666666666667",
        },
        {
          contentType = "image/jpeg",
          disabled = false,
          key = "logo",
          src = "logo.png",
          type = "file",
          value = "",
        },
        {
          contentType = "",
          disabled = false,
          key = "w",
          src = "",
          type = "text",
          value = "514.5666666666667",
        },
        {
          contentType = "",
          disabled = false,
          key = "x",
          src = "",
          type = "text",
          value = "0",
        },
        {
          contentType = "",
          disabled = false,
          key = "y",
          src = "",
          type = "text",
          value = "1.4333333333333333",
        },
      },
    })
  end)

  it("parses graphql", function()
    local file = h.expand_path("fixtures/export/export_2.http")
    vim.cmd.edit(file)

    local collection = export.export_requests() or {}
    local request = collection.item[1].item[3].request

    assert.is_same("POST", request.method)
    assert.has_properties(request.body, {
      mode = "graphql",
      graphql = {
        query = "query Person($id: ID) { person(personID: $id) { name } } ",
        variables = { id = 1 },
      },
    })
  end)

  it("parses variables", function()
    vim.cmd.edit(h.expand_path("fixtures/export/export_2.http"))

    require("kulala").set_selected_env("dev")
    vim.env.cookie_value = "session_id_value"

    local collection = export.export_requests() or {}

    local group = collection.item[1]
    local item = group.item[4]

    local variables = vim.iter(collection.variable):fold({}, function(acc, v)
      acc[v.key] = v.value
      return acc
    end)

    sort(item.request.header, "key")

    assert.has_properties(item.request, {
      method = "POST",
      url = { raw = "{{URL}}/post" },
      header = {
        { key = "Accept", value = "{{header_content_type}}", disabled = false },
        { disabled = false, key = "Content-Type", value = "application/json" },
      },
      body = {
        mode = "raw",
        raw = '{\n  "username": "{{USERNAME}}",\n  "password": "{{PASSWORD}}"\n}',
      },
    })

    assert.has_properties(variables, {
      PASSWORD = "bananas",
      URL = "https://httpbin.org",
      USERNAME = "gorillamoe",
      cookie_name = "session_id",
      cookie_value = "session_id_value",
      header_content_type = "plain/text",
      var_name_3 = "var_value_3",
      var_name_4 = "var_value_4",
    })
  end)

  describe("parses authentication", function()
    it("basic authentication", function()
      local file = h.expand_path("fixtures/export/export_3.http")
      vim.cmd.edit(file)

      local collection = export.export_requests() or {}
      local request = collection.item[1].item[1].request

      sort(request.auth, "key")

      assert.has_properties(request.auth, {
        type = "basic",
        basic = {
          {
            key = "username",
            value = "user",
          },
          {
            key = "password",
            value = "pass",
          },
        },
      })
    end)

    it("bearer token", function()
      local file = h.expand_path("fixtures/export/export_3.http")
      vim.cmd.edit(file)

      local collection = export.export_requests() or {}
      local request = collection.item[1].item[2].request

      sort(request.auth, "key")

      assert.has_properties(request.auth, {
        type = "bearer",
        bearer = {
          {
            key = "token",
            value = "secret_token",
          },
        },
      })
    end)

    pending("digest token", function()
      local file = h.expand_path("fixtures/export/export_3.http")
      vim.cmd.edit(file)

      local collection = export.export_requests() or {}
      local request = collection.item[1].item[3].request

      sort(request.auth, "key")

      assert.has_properties(request.auth, {
        type = "bearer",
        bearer = {
          {
            key = "token",
            value = "secret_token",
          },
        },
      })
    end)

    pending("oauth2 token", function()
      local file = h.expand_path("fixtures/export/export_3.http")
      vim.cmd.edit(file)

      local collection = export.export_requests() or {}
      local request = collection.item[1].item[4].request

      sort(request.auth, "key")

      assert.has_properties(request.auth, {
        type = "bearer",
        bearer = {
          {
            key = "token",
            value = "secret_token",
          },
        },
      })
    end)
  end)
end)
