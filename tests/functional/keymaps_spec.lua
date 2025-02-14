---@diagnostic disable: undefined-field, redefined-local
local GLOBALS = require("kulala.globals")
local CONFIG = require("kulala.config")
local KEYMAPS = require("kulala.config.keymaps")
local kulala = require("kulala")

local kulala_name = GLOBALS.UI_ID

local h = require("test_helper")

describe("keymaps", function()
  local lines, expected, http_buf, ui_buf

  local global_keymaps = KEYMAPS.default_global_keymaps
  local kulala_keymaps = KEYMAPS.default_kulala_keymaps
  local keymaps_n, keymaps_v

  vim.g.mapleader = ","

  before_each(function()
    h.delete_all_maps()
  end)

  after_each(function()
    h.delete_all_bufs()
  end)

  describe("global keymaps", function()
    before_each(function()
      CONFIG.setup({
        global_keymaps = {
          ["Inspect current request"] = {
            "<leader>RI",
            function() end,
          },
          ["Open scratchpad"] = false,
        },
      })

      keymaps_n = vim.tbl_keys(h.get_maps())
      keymaps_v = vim.tbl_keys(h.get_maps(nil, "v"))
    end)

    it("sets default keymaps", function()
      http_buf = h.create_buf(lines, "test.txt")

      expected = global_keymaps["Open kulala"][1]
      assert.is_true(vim.tbl_contains(keymaps_n, expected))

      expected = global_keymaps["Send request"][1]
      assert.is_true(vim.tbl_contains(keymaps_v, expected))

      expected = global_keymaps["Jump to next request"][1]
      assert.is_false(vim.tbl_contains(keymaps_n, expected))
    end)

    it("sets filetype keymaps", function()
      vim.cmd.e("test.http")
      http_buf = vim.fn.bufnr()

      keymaps_n = vim.tbl_keys(h.get_maps(http_buf))

      expected = global_keymaps["Find request"][1]
      assert.is_true(vim.tbl_contains(keymaps_n, expected))
    end)

    it("sets and disables custom keymaps", function()
      expected = "<leader>RI"
      assert.is_true(vim.tbl_contains(keymaps_n, expected))
      assert.is_false(vim.tbl_contains(keymaps_n, global_keymaps["Open scratchpad"][1]))
    end)
  end)

  describe("global keymaps", function()
    it("disables default keymaps", function()
      CONFIG.setup({ global_keymaps = false })

      local keymaps_n = vim.tbl_keys(h.get_maps())
      expected = global_keymaps["Open kulala"][1]
      assert.is_false(vim.tbl_contains(keymaps_n, expected))
    end)
  end)

  describe("local keymaps", function()
    before_each(function()
      h.Fs:stub_read_file({ [GLOBALS.BODY_FILE] = h.load_fixture("fixtures/request_2_headers_body.txt") })

      CONFIG.setup({
        default_view = "body",
        kulala_keymaps = {
          ["Show headers"] = {
            "HH",
            function() end,
          },
          ["Show headers and body"] = false,
        },
      })

      kulala.open()
      ui_buf = vim.fn.bufnr(kulala_name)

      keymaps_n = vim.tbl_keys(h.get_maps(ui_buf))
    end)

    after_each(function()
      kulala.close()
      h.Fs:read_file_reset()
    end)

    it("sets default keymaps", function()
      expected = kulala_keymaps["Show body"][1]
      assert.is_true(vim.tbl_contains(keymaps_n, expected))
    end)

    it("sets custom keymaps", function()
      assert.is_true(vim.tbl_contains(keymaps_n, "HH"))

      expected = kulala_keymaps["Show headers and body"][1]
      assert.is_false(vim.tbl_contains(keymaps_n, expected))
    end)

    it("disbales default keymaps", function()
      kulala.close()
      CONFIG.setup({ kulala_keymaps = false })

      kulala.open()
      ui_buf = vim.fn.bufnr(kulala_name)

      keymaps_n = vim.tbl_keys(h.get_maps(ui_buf))

      expected = kulala_keymaps["Show body"][1]
      assert.is_false(vim.tbl_contains(keymaps_n, expected))
    end)
  end)
end)
