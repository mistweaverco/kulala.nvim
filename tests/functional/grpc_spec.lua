---@diagnostic disable: undefined-field, redefined-local
local fs = require("kulala.utils.fs")
local h = require("test_helper")
local kulala = require("kulala")
local kulala_config = require("kulala.config").get()
local parser = require("kulala.parser.request")

describe("grpc", function()
  local curl, system, wait_for_requests
  local ui_buf, result, expected

  describe("parses grpc request", function()
    before_each(function()
      h.delete_all_bufs()

      stub(vim.fn, "executable", function(_)
        return 1
      end)

      curl = h.Curl.stub({
        ["*"] = {
          stdout = [[ { "message": "Hello World" } ]],
        },
      })

      system = h.System.stub({ "grpcurl" }, {
        on_call = function(system)
          curl.request(system)
        end,
      })

      wait_for_requests = function(requests_no)
        system:wait(3000, function()
          ui_buf = h.get_kulala_buf()
          return curl.requests_no == requests_no and ui_buf > 0
        end)
      end

      kulala_config.default_view = "headers_body"
    end)

    after_each(function()
      h.delete_all_bufs()
      curl.reset()
      system.reset()
      vim.fn.executable:revert()
    end)

    it("builds grpc command", function()
      h.create_buf(
        ([[
          # @grpc-global-import-path ../protos 
          # @grpc-global-proto helloworld.proto
          GRPC localhost:50051 helloworld.Greeter/SayHello

          {"name": "world"}
      ]]):to_table(true),
        "test.http"
      )

      result = parser.parse() or {}
      result = h.to_string(result.cmd):gsub("\n", " ")

      local import_path = fs.get_file_path("../protos")

      assert.has_string(result, "grpcurl")
      assert.has_string(result, '-d {"name": "world"}')
      assert.has_string(result, "-import-path " .. import_path)
      assert.has_string(result, "-proto helloworld.proto")
      assert.has_string(result, "localhost:50051 helloworld.Greeter/SayHello")
    end)

    it("builds grpc substituting variables", function()
      h.create_buf(
        ([[
          @server=localhost:50051
          @service=helloworld.Greeter
          @flags=-import-path ../protos-variable -proto helloworld.proto
          # @grpc-protoset my-protos.bin
          # @grpc-import-path ../protos-global-local
          # @grpc-global-import-path ../protos-global 
          GRPC {{flags}} {{server}} {{service}}/SayHello

          {"name": "world"}
      ]]):to_table(true),
        "test.http"
      )

      result = parser.parse() or {}
      result = h.to_string(result.cmd):gsub("\n", " ")

      local import_path = fs.get_file_path("../protos")

      assert.has_string(result, "grpcurl")
      assert.has_string(result, '-d {"name": "world"}')
      assert.has_string(result, "-import-path " .. import_path)
      assert.has_string(result, "-proto helloworld.proto")
      assert.has_string(result, "-protoset my-protos.bin")
      assert.has_string(result, "localhost:50051 helloworld.Greeter/SayHello")
    end)

    it("processes global and local metadata", function()
      h.create_buf(
        ([[
          # @grpc-global-import-path ../protos 
          # @grpc-global-proto helloworld.proto
          GRPC localhost:50051 helloworld.Greeter/SayHello

          {"name": "world"}

          ###

          # @grpc-plaintext
          GRPC localhost:50051 list
      ]]):to_table(true),
        "test.http"
      )

      parser.parse() -- parse the first request to set global metadata
      h.send_keys("9j")

      result = parser.parse() or {}
      result = h.to_string(result.cmd):gsub("\n", " ")

      local import_path = fs.get_file_path("../protos")

      assert.has_string(result, "-import-path " .. import_path)
      assert.has_string(result, "-proto helloworld.proto")
      assert.has_string(result, "-plaintext")
      assert.has_string(result, "localhost:50051 list")
    end)

    it("runs grpc request and sets content type: json", function()
      h.create_buf(
        ([[
          # @grpc-global-import-path ../protos 
          # @grpc-global-proto helloworld.proto
          GRPC localhost:50051 describe helloworld.Greeter.SayHello
      ]]):to_table(true),
        "test.http"
      )

      kulala.run_all()
      wait_for_requests(1)

      result = h.get_buf_lines(ui_buf):to_string(true)

      assert.has_string(result, "Content-Type: application/json")
      assert.has_string(result, '{\n"message": "Hello World"\n}')
    end)
  end)
end)
