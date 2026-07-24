describe("ui markdown get_body_ft", function()
  local get_body_ft

  before_each(function()
    get_body_ft = require("kulala.ui.markdown").get_body_ft
  end)

  it("prefers kulala-core json body type", function()
    assert.are.equal("json", get_body_ft("text/plain", "json"))
  end)

  it("detects json media types", function()
    assert.are.equal("json", get_body_ft("application/json", "text"))
    assert.are.equal("json", get_body_ft("application/problem+json", nil))
  end)

  it("detects xml and html media types", function()
    assert.are.equal("xml", get_body_ft("application/xml", "text"))
    assert.are.equal("html", get_body_ft("text/html; charset=utf-8", "text"))
  end)

  it("falls back to text", function()
    assert.are.equal("text", get_body_ft(nil, nil))
    assert.are.equal("text", get_body_ft("text/plain", "text"))
  end)
end)
