---@diagnostic disable: undefined-field
local Config = require("kulala.config")
local Db = require("kulala.db")
local Fs = require("kulala.utils.fs")
local h = require("test_helper")

local function run_cli(args)
  table.insert(args, "--mono")
  _G.arg = args

  local cli = loadfile("lua/cli/kulala_cli.lua")
  return cli()
end

describe("cli", function()
  local curl, system
  local output, exit_code
  local result

  before_each(function()
    h.delete_all_bufs()
    Db.global_update().responses = {}

    stub(os, "exit", function(code)
      exit_code = code
    end)

    curl = h.Curl.stub {
      ["https://httpbin.org/advanced_1"] = {
        body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
      },
      ["https://httpbin.org/advanced_2"] = {
        body = h.load_fixture("fixtures/advanced_A_2_body.txt"),
      },
      ["https://httpbin.org/advanced_b"] = {
        body = h.load_fixture("fixtures/advanced_B_body.txt"),
      },
      ["https://httpbin.org/get"] = { body = "" },
    }

    system = h.System.stub({ "curl" }, {
      on_call = function(system)
        curl.request(system)
      end,
    })

    output = h.Output.stub() -- change to h.Output.spy() to see output in tests
  end)

  after_each(function()
    h.delete_all_bufs()
    curl.reset()
    system.reset()
    output.reset()

    os.exit:revert()
  end)

  it("runs all requests in file", function()
    local path = h.expand_path("requests/advanced_A.http")
    run_cli { path }

    assert.is_same(0, exit_code)
    assert.is_same(2, curl.requests_no)
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_1")
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_2")
    assert.has_string(output.log, "Status: OK")
  end)

  it("runs requests in several files", function()
    local path = h.expand_path("requests/advanced_A.http")
    local path_2 = h.expand_path("requests/advanced_B.http")
    run_cli { path, path_2 }

    assert.is_same(3, curl.requests_no)
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_1")
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_2")
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_b")
  end)

  it("runs all request files in directory", function()
    local path = h.expand_path("requests")
    run_cli { path, "--list" }

    result = vim
      .iter(output.log)
      :filter(function(line)
        return line:match("File:")
      end)
      :totable()

    assert.is_same(9, #result)
  end)

  it("filters requests", function()
    local path = h.expand_path("requests/advanced_A.http")
    local path_2 = h.expand_path("requests/advanced_B.http")
    run_cli { path, path_2, "-n", "REQUEST_FOOBAR", "-l", "32" }

    assert.is_same("https://httpbin.org/advanced_2", curl.requests[1])
    assert.is_same("https://httpbin.org/advanced_b", curl.requests[2])
  end)

  it("lists requests", function()
    local path = h.expand_path("requests/advanced_A.http")
    run_cli { path, "--list" }

    assert.has_string(output.log, "requests/advanced_A.http")
    assert.has_string(output.log, "8    Request 1")
    assert.has_string(output.log, "POST https://httpbin.org/advanced_1")
    assert.has_string(output.log, "32   POST https://httpbin.org/advanced_2")
    assert.has_string(output.log, "POST https://httpbin.org/advanced_2")
  end)

  it("uses different environments", function()
    local path = h.expand_path("requests/advanced_A.http")
    run_cli { path, "-e", "prod" }
    assert.is_same("prod", Config.options.default_env)
  end)

  it("shows with different views", function()
    local path = h.expand_path("requests/advanced_A.http")
    run_cli { path, "-v", "report" }

    assert.has_string(output.log, "Line URL")
    assert.has_string(output.log, "Line URL")
    assert.has_string(output.log, "8    https://httpbin.org/advanced_1")
    assert.has_string(output.log, "32   https://httpbin.org/advanced_2")
    assert.has_string(output.log, "Summary             Total")
    assert.has_string(output.log, "Successful          Failed")
    assert.has_string(output.log, "Requests            2")
    assert.has_string(output.log, "Asserts             0")
  end)

  it("halts on error", function()
    curl.stub {
      ["https://httpbin.org/advanced_1"] = {
        code = 124,
        body = "",
      },
    }

    local path = h.expand_path("requests/advanced_A.http")
    run_cli { path, "--halt" }

    assert.is_same(1, exit_code)
    assert.is_same(1, curl.requests_no)
    assert.has_string(output.log, "Status: FAIL")
  end)

  -- pending, as fmt-dependencies install in minit.lua gives weird errors in lazy.nvim async runner
  pending("it::imports HTTP files", function()
    local file = h.expand_path("fixtures/export/export.json")
    run_cli { "import", "--from", "postman", file }

    Fs.delete_file(h.expand_path("fixtures/export/export.http"))
    assert.has_string(output.log, "Converted PostMan Collection")
  end)

  it("exports HTTP file", function()
    stub(Fs, "write_json", true)

    run_cli { "export", h.expand_path("fixtures/export") }
    assert.has_string(output.log, "Exported collection:")

    Fs.write_json:revert()
  end)

  it("allows to supply prompt variables with CLI", function()
    local path = h.expand_path("requests/prompt.http")

    run_cli { path, "--sub", "PROMPT_VAR=prompt" }

    assert.is_same(0, exit_code)
    assert.is_same(1, curl.requests_no)
    assert.is_same("http://httpbin.org/prompt", curl.requests[1])
  end)

  describe("config override", function()
    it("loads custom config file with -c option", function()
      local config_path = h.expand_path("fixtures/cli_configs/custom_config.lua")
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "-c", config_path }

      assert.is_same("custom_env", Config.options.default_env)
      assert.is_same(true, Config.options.halt_on_error)
      assert.is_same("headers", Config.options.ui.default_view)
    end)

    it("loads custom config file with --config option", function()
      local config_path = h.expand_path("fixtures/cli_configs/custom_config.lua")
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--config", config_path }

      assert.is_same("custom_env", Config.options.default_env)
    end)

    it("errors when config file not found", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "-c", "/nonexistent/config.lua" }

      -- os.exit is stubbed, so we check the error was reported
      assert.has_string(output.log, "Config file not found")
    end)

    it("overrides simple config value with --set", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--set", "default_env=set_env" }

      assert.is_same("set_env", Config.options.default_env)
    end)

    it("overrides nested config value with --set", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--set", "ui.default_view=verbose" }

      assert.is_same("verbose", Config.options.ui.default_view)
    end)

    it("overrides boolean config value with --set", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--set", "halt_on_error=true" }

      assert.is_same(true, Config.options.halt_on_error)
    end)

    it("overrides number config value with --set", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--set", "request_timeout=5000" }

      assert.is_same(5000, Config.options.request_timeout)
    end)

    it("applies multiple --set options", function()
      local path = h.expand_path("requests/advanced_A.http")

      -- Multiple --set values are passed space-separated after the flag
      run_cli { path, "--set", "default_env=multi_env", "halt_on_error=true" }

      assert.is_same("multi_env", Config.options.default_env)
      assert.is_same(true, Config.options.halt_on_error)
    end)

    it("--set takes precedence over -c config", function()
      local config_path = h.expand_path("fixtures/cli_configs/custom_config.lua")
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "-c", config_path, "--set", "default_env=override_env" }

      -- custom_config.lua sets default_env="custom_env", but --set should win
      assert.is_same("override_env", Config.options.default_env)
      -- Other values from custom_config.lua should still apply
      assert.is_same(true, Config.options.halt_on_error)
    end)

    it("handles deeply nested --set paths", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--set", "ui.report.successHighlight=TestGreen" }

      assert.is_same("TestGreen", Config.options.ui.report.successHighlight)
    end)

    it("handles empty --set value", function()
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "--set", "default_env=" }

      assert.is_same("", Config.options.default_env)
    end)

    it("deep merges nested config values", function()
      local config_path = h.expand_path("fixtures/cli_configs/nested_config.lua")
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "-c", config_path, "--set", "ui.report.errorHighlight=OverrideRed" }

      -- Values from nested_config.lua should be preserved
      assert.is_same("CustomGreen", Config.options.ui.report.successHighlight)
      -- But the --set override should win
      assert.is_same("OverrideRed", Config.options.ui.report.errorHighlight)
    end)

    it("-e flag takes precedence over config file default_env", function()
      local config_path = h.expand_path("fixtures/cli_configs/custom_config.lua")
      local path = h.expand_path("requests/advanced_A.http")

      run_cli { path, "-c", config_path, "-e", "flag_env" }

      -- -e flag should override custom_config.lua's default_env
      assert.is_same("flag_env", Config.options.default_env)
    end)
  end)
end)
