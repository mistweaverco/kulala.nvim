---@diagnostic disable: undefined-field, redefined-local

local export = require("kulala.cmd.export")
local fs = require("kulala.utils.fs")
local h = require("test_helper")

local function sort(tbl, key)
  table.sort(tbl, function(a, b)
    return a[key or "id"] < b[key or "id"]
  end)
end

describe("export to Postman", function()
  local buf, result

  before_each(function()
    h.delete_all_bufs()
    stub(fs, "write_json", true)
  end)

  after_each(function()
    fs.write_json:revert()
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
      url = "https://httpbin.org/post",
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
      request = { method = "GET", url = "https://httpbin.org/get?param1=value1&param2=value" },
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

    assert.is_same(4, #collection.variable)
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
end)
