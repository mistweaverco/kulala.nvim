local Json = require("kulala.utils.json")
local Logger = require("kulala.logger")

describe("kulala.utils.json", function()
  it("parses valid json", function()
    local value, err = Json.parse('{"a":1}', { verbose = true })
    assert.is_nil(err)
    assert.are.same({ a = 1 }, value)
  end)

  it("returns error on invalid json when verbose", function()
    Logger.error = function() end -- Suppress error logs during test
    local value, err = Json.parse("{bad", { verbose = true })
    assert.is_nil(value)
    assert.is_string(err)
  end)

  it("encodes with sorted keys when requested", function()
    local encoded = Json.encode({ b = 2, a = 1 }, { sort = true })
    assert.are.same('{"a": 1, "b": 2}', encoded)
  end)
end)
