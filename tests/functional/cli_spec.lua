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
end)
