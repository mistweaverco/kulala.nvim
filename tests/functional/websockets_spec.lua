---@diagnostic disable: undefined-field, redefined-local
local h = require("test_helper")
local kulala = require("kulala")
local kulala_config = require("kulala.config")
local ws = require("kulala.cmd.websocket")

describe("websockets", function()
  local system, wait_for_requests
  local ui_buf, ui_buf_tick, result, expected

  before_each(function()
    h.delete_all_bufs()

    stub(vim.fn, "executable", function(_)
      return 1
    end)

    system = h.System.stub({ "websocat" }, {
      on_call = function(system)
        system.async = true
      end,
      write = function(_, data)
        system.add_log { "write", data }
      end,
      kill = function(_, signal)
        system.add_log { "kill", signal }
        system.add_log { "on_exit" }
        system.args.opts.on_exit(system)
      end,
      write_to = function(event, data)
        system.args.opts[event](data, data)
        system.add_log { event, data }
      end,
    })

    ui_buf_tick = 0

    wait_for_requests = function(requests_no)
      system:wait(3000, function()
        ui_buf = h.get_kulala_buf()
        local tick = ui_buf > 0 and vim.api.nvim_buf_get_changedtick(ui_buf) or 0

        if #system.log >= requests_no and ui_buf > 0 and tick > ui_buf_tick then
          ui_buf_tick = tick
          return true
        end
      end)
    end

    kulala_config.setup { default_view = "body" }

    h.create_buf(
      ([[
          WS wss://echo.websocket.org

          {"name": "world"}
      ]]):to_table(true),
      "test.http"
    )
  end)

  after_each(function()
    h.delete_all_bufs()
    system.reset()
    ws.connection = nil
    vim.fn.executable:revert()
  end)

  it("connects to websocket and sends body", function()
    kulala.run()
    wait_for_requests(1)

    result = system.args.cmd
    assert.are.same({ "websocat", "wss://echo.websocket.org" }, result)

    result = h.get_buf_lines(ui_buf)

    assert.has_string(result, "Code: 0")
    assert.has_string(result, "Status: 0")
    assert.has_string(result, "URL: WS wss://echo.websocket.org")
    assert.has_string(result, "Connected... Waiting for data.")
    assert.has_string(result, "Press <CR>\\<S-CR> to send message and <C-c> to close connection.")

    assert.has_properties(system.log[1], { "write", '{"name": "world"}\n' })
  end)

  it("receives messages", function()
    kulala.run()
    wait_for_requests(1)

    system.opts.write_to("stdout", "Hello, world!\n")
    wait_for_requests(2)

    result = h.get_buf_lines(ui_buf)
    assert.has_string(result, "=> Hello, world!")
  end)

  it("sends messages", function()
    kulala.run()
    wait_for_requests(1)

    h.set_buf_lines(ui_buf, { "Sending..." }, -1, -1)

    vim.api.nvim_set_current_win(h.get_kulala_win())
    h.send_keys("G")
    ws.send()

    wait_for_requests(2)
    assert.has_properties(system.log[2], { "write", "Sending...\n" })

    result = h.get_buf_lines(ui_buf)
  end)

  it("shows errors", function()
    kulala_config.options.default_view = "verbose"

    kulala.run()
    wait_for_requests(1)

    system.opts.write_to("stderr", "Error: Connection closed\n")
    wait_for_requests(2)

    result = h.get_buf_lines(ui_buf)
    assert.has_string(result, "Code: -1")
    assert.has_string(result, "Error: Connection closed")
  end)

  it("closes connection", function()
    kulala.run()
    wait_for_requests(1)

    vim.api.nvim_set_current_win(h.get_kulala_win())
    ws.close()

    wait_for_requests(3)
    assert.has_properties(system.log[2], { "kill", 15 })

    result = h.get_buf_lines(ui_buf)
    assert.has_string(result, "Code: -1")
    assert.has_string(result, "Connection closed")
  end)
end)
