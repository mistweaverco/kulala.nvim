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

  it("has", function()
    local h = HTTPHeaders:new()
    h["ACCEPT"] = "text/plain"
    assert.is_true(h:has("Accept"))
    assert.is_true(h:has("accept"))
    assert.is_false(h:has("Axxept"))
  end)

  it("has value", function()
    local h = HTTPHeaders:new()
    h["ACCEPT"] = "text/plain"
    assert.is_true(h:has("Accept", "text/plain"))
    assert.is_true(h:has("accept", "text/plain"))
    assert.is_true(h:has("accept", "Text/plain"))
    assert.is_false(h:has("Accept", "text/json"))
  end)

  it("has exact", function()
    local h = HTTPHeaders:new()
    h["X-REQUEST-TYPE"] = "graphql"
    assert.is_true(h:has_exact("X-REQUEST-TYPE"))
    assert.is_false(h:has_exact("x-request-type"))
  end)

  it("has exact value", function()
    local h = HTTPHeaders:new()
    h["X-REQUEST-TYPE"] = "graphql"
    assert.is_true(h:has_exact("X-REQUEST-TYPE", "graphql"))
    assert.is_false(h:has_exact("x-request-type", "GRAPHQL"))
    assert.is_false(h:has_exact("X-REQUEST-TYPE", "GRAPHQL"))
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
      { "Accept", "text/plain" },
      { "aCCEPT", "*/*" },
    }
    assert.same(expected, flat)
  end)
end)
