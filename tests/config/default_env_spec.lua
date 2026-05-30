local CONFIG = require("kulala.config")
local ENV = require("kulala.parser.env")

describe("default_env", function()
  before_each(function()
    vim.g.kulala_selected_env = nil
    require("kulala").setup(require("kulala.test_helper.kulala_core").config { default_env = "default" })
    require("kulala.db").update().selected_env = nil
  end)

  it("uses default_env from setup when no env is selected", function()
    assert.are.equal("default", ENV.get_current_env())
    assert.are.equal("default", require("kulala").get_selected_env())
  end)

  it("keeps default_env after a second setup with unrelated options", function()
    CONFIG.setup { global_keymaps = false }
    assert.are.equal("default", ENV.get_current_env())
  end)
end)
