local HTTPHeaders = require("kulala.parser.headers")

describe("headers", function()
  it("empty", function()
    local h = HTTPHeaders:new()
    assert.is_false(h:has("accept"))
    assert.is_nil(h["accept"])
  end)
  it("case insensitive get/set", function()
    local h = HTTPHeaders:new()
    h["ACCEPT"] = "text/plain"
    assert.same({ "text/plain" }, h["accept"])
  end)
  it("has value", function()
    local h = HTTPHeaders:new()
    h["ACCEPT"] = "text/plain"
    assert.is_true(h:has("Accept"))
    assert.is_true(h:has_value("Accept", "text/plain"))
    assert.is_false(h:has_value("Accept", "text/json"))
  end)
  it("multiple header values", function()
    local h = HTTPHeaders:new()
    h["accept"] = "text/html"
    h["Accept"] = "text/plain"
    h["aCCEPT"] = "*/*"
    assert.same({ "text/html", "text/plain", "*/*" }, h["Accept"])
  end)
  it("flat pairs", function()
    local h = HTTPHeaders:new()
    h["accept"] = "text/html"
    h["Accept"] = "text/plain"
    h["aCCEPT"] = "*/*"
    local flat = {}
    for _, v in h:flatpairs() do
      flat[#flat + 1] = v
    end
    local expected = {
      { "accept", "text/html" },
      { "accept", "text/plain" },
      { "accept", "*/*" },
    }
    assert.same(expected, flat)
  end)
end)
