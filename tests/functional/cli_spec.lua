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

  before_each(function()
    h.delete_all_bufs()

    stub(os, "exit", function(code)
      exit_code = code
    end)

    curl = h.Curl.stub({
      ["*"] = {
        stats = h.load_fixture("fixtures/stats.json"),
        headers = h.load_fixture("fixtures/request_2_headers.txt"),
      },
      ["https://httpbin.org/advanced_1"] = {
        body = h.load_fixture("fixtures/advanced_A_1_body.txt"),
      },
      ["https://httpbin.org/advanced_2"] = {
        body = h.load_fixture("fixtures/advanced_A_2_body.txt"),
      },
      ["https://httpbin.org/advanced_b"] = {
        body = h.load_fixture("fixtures/advanced_B_body.txt"),
      },
    })

    system = h.System.stub({ "curl" }, {
      on_call = function(system)
        curl.request(system)
      end,
    })

    output = h.Output.stub()
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
    run_cli({ path })

    assert.is_same(0, exit_code)
    assert.is_same(2, curl.requests_no)
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_1")
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_2")
  end)

  it("#wip runs requests in several files", function()
    local path = h.expand_path("requests/advanced_A.http")
    local path_2 = h.expand_path("requests/advanced_B.http")
    run_cli({ path, path_2 })

    LOG("curl: ", curl.requests)
    assert.is_same(3, curl.requests_no)
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_1")
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_2")
    assert.has_string(output.log, "URL: POST https://httpbin.org/advanced_b")
  end)

  it("runs all request files in directory", function()
    ---
  end)

  it("filters requests", function()
    ---
  end)

  it("lists requests", function()
    ---
  end)

  it("uses different environments", function() end)

  it("shows with different views", function()
    ---
  end)

  it("halts on error", function()

    ---
  end)

  it("outputs in color", function()
    ---
  end)
end)
