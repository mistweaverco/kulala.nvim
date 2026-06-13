local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local Sessions = require("kulala.vim-sessions")

describe("vim-sessions", function()
  local saved_global_data
  local saved_config
  local saved_vim_g

  before_each(function()
    saved_global_data = vim.deepcopy(DB.global_data)
    saved_config = {
      default_view = CONFIG.get().default_view,
      display_mode = CONFIG.get().display_mode,
      session = vim.deepcopy(CONFIG.get().session),
    }
    saved_vim_g = {
      KulalaGlobalData = vim.g.KulalaGlobalData,
      KulalaDefaultView = vim.g.KulalaDefaultView,
      KulalaDisplayMode = vim.g.KulalaDisplayMode,
      KulalaSelectedEnv = vim.g.KulalaSelectedEnv,
      kulala_selected_env = vim.g.kulala_selected_env,
    }

    CONFIG.set { session = { restore = true } }
  end)

  after_each(function()
    DB.global_data = saved_global_data
    CONFIG.set(saved_config)

    vim.g.KulalaGlobalData = saved_vim_g.KulalaGlobalData
    vim.g.KulalaDefaultView = saved_vim_g.KulalaDefaultView
    vim.g.KulalaDisplayMode = saved_vim_g.KulalaDisplayMode
    vim.g.KulalaSelectedEnv = saved_vim_g.KulalaSelectedEnv
    vim.g.kulala_selected_env = saved_vim_g.kulala_selected_env
  end)

  it("saves and restores response history", function()
    DB.global_data.responses = {
      {
        id = "1:10",
        body = "hello",
        buf_name = "requests.http",
        file = "/tmp/requests.http",
        line = 10,
        buf = 99,
      },
    }
    DB.global_data.current_response_pos = 1
    DB.global_data.previous_response_pos = 0

    Sessions.save_state()

    local saved = vim.json.decode(vim.g.KulalaGlobalData)
    assert.is_nil(saved.responses[1].buf)

    DB.global_data = {
      responses = {},
      current_response_pos = 0,
      previous_response_pos = 0,
      replay = nil,
    }

    Sessions.restore_state()

    assert.are.equal(1, #DB.global_data.responses)
    assert.are.equal("hello", DB.global_data.responses[1].body)
    assert.are.equal(1, DB.global_data.current_response_pos)
  end)

  it("restores UI options and selected env", function()
    CONFIG.set { default_view = "headers", display_mode = "float" }
    vim.g.kulala_selected_env = "staging"

    Sessions.save_state()
    CONFIG.set { default_view = "body", display_mode = "split" }
    vim.g.kulala_selected_env = nil

    Sessions.restore_state()

    assert.are.equal("headers", CONFIG.get().default_view)
    assert.are.equal("float", CONFIG.get().display_mode)
    assert.are.equal("staging", vim.g.kulala_selected_env)
  end)

  it("deletes stale kulala UI buffers on session load", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(buf, "kulala://ui")
    vim.bo[buf].filetype = "kulala_ui"

    vim.g.KulalaGlobalData = vim.json.encode {
      responses = {},
      current_response_pos = 0,
      previous_response_pos = 0,
      replay = nil,
    }

    Sessions.load_session_hook()

    assert.is_false(vim.api.nvim_buf_is_valid(buf))
  end)

  it("remaps response buffer ids from buf_name", function()
    vim.cmd("new")
    local http_buf = vim.api.nvim_get_current_buf()
    local buf_name = vim.fn.tempname() .. ".http"
    vim.api.nvim_buf_set_name(http_buf, buf_name)

    vim.g.KulalaGlobalData = vim.json.encode {
      responses = {
        {
          id = "1:1",
          body = "ok",
          buf_name = buf_name,
          line = 1,
        },
      },
      current_response_pos = 1,
      previous_response_pos = 0,
      replay = nil,
    }

    Sessions.restore_state()

    assert.are.equal(http_buf, DB.global_data.responses[1].buf)
    assert.are.equal(http_buf, DB.current_buffer)
  end)
end)
