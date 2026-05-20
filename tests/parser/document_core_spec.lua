local Bridge = require("kulala.cmd.kulala_core_bridge")
local CONFIG = require("kulala.config")
local DocCore = require("kulala.parser.document_core")

describe("document_core", function()
  before_each(function()
    require("kulala").setup(require("test_helper.kulala_core").config {})
  end)
  it("maps kulala-core blocks to document requests", function()
    local content = table.concat({
      "### Request A",
      "GET https://example.com/a",
      "",
      "### Request B",
      "POST https://example.com/b",
      "Content-Type: application/json",
      "",
      '{"ok":true}',
    }, "\n")

    local doc = Bridge.parse_document(content, nil, vim.uv.cwd())
    assert.is_not_nil(doc)

    local requests = DocCore.to_document_requests(doc, "sample.http")
    assert.are.same(2, #requests)
    assert.are.same("GET", requests[1].method)
    assert.are.same("https://example.com/a", requests[1].url)
    assert.are.same("POST", requests[2].method)
    assert.are.same('{"ok":true}', requests[2].body)
  end)

  it("skips shared-only blocks without url", function()
    local content = table.concat({
      "### Shared",
      "@token = secret",
      "",
      "### Request",
      "GET https://example.com/",
    }, "\n")

    local doc = Bridge.parse_document(content, nil, vim.uv.cwd())
    local requests = DocCore.to_document_requests(doc, "shared.http")

    assert.are.same(1, #requests)
    assert.are.same("secret", requests[1].variables.token)
  end)
end)
