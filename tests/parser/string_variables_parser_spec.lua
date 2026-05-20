local VarParser = require("kulala.parser.string_variables_parser")

describe("string_variables_parser", function()
  it("substitutes document and env variables", function()
    local result = VarParser.parse("Hello {{name}} from {{region}}", {
      name = "Kulala",
    }, {
      region = "EU",
    }, true)

    assert.are.same("Hello Kulala from EU", result)
  end)

  it("leaves unknown variables when silent", function()
    local result = VarParser.parse("{{missing}}", {}, {}, true)
    assert.are.same("{{missing}}", result)
  end)

  it("resolves nested env keys", function()
    local result = VarParser.parse("{{db.host}}", {}, { db = { host = "localhost" } }, true)
    assert.are.same("localhost", result)
  end)
end)
