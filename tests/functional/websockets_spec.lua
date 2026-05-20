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

    h.KulalaCore.stub {
      ["wss://echo.websocket.org"] = { body = '{"name": "world"}' },
    }

    system = h.System.stub({ "kulala-core", "--websocket" }, {
      on_call = function(system)
        if vim.iter(system.args.cmd):any(function(p)
          return p == "--websocket"
        end) then
          system.async = true
          system.websocket = true
          local opts = system.args.opts or {}
          vim.schedule(function()
            if opts.stdout then opts.stdout(system, '{"type":"ready"}\n') end
            if opts.stdin and system.write then
              local payload = vim.fn.readfile(system.args.cmd[#system.args.cmd])
              local ok, data = pcall(vim.json.decode, payload[1] or "{}")
              if ok and data.body then system.write(data.body .. "\n") end
            end
          end)
          return
        end
        if h.KulalaCore.is_invocation(system.args.cmd) then h.KulalaCore.handle(system) end
      end,
      write = function(_, data)
        system.add_log { "write", data or "" }
      end,
      kill = function(_, signal)
        system.add_log { "kill", signal }
        system.add_log { "on_exit" }
        system.args.opts.on_exit(system)
      end,
      write_to = function(event, data)
        local fn = system.args.opts[event]
        if fn then fn(system, data) end
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

    require("kulala").setup(require("test_helper.kulala_core").config { default_view = "body" })

    h.create_buf(
      ([[
          ### WebSocket
          WS wss://echo.websocket.org

          {"name": "world"}
      ]]):to_table(true),
      "test.http"
    )
  end)

  after_each(function()
    h.delete_all_bufs()
    h.KulalaCore.reset()
    system.reset()
    ws.connection = nil
    vim.fn.executable:revert()
  end)

  it("connects to websocket and sends body", function()
    kulala.run()
    wait_for_requests(1)

    assert.is_true(system.websocket)

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

    system.write_to("stdout", '{"type":"message","data":"Hello, world!"}\n')
    wait_for_requests(2)

    result = h.get_buf_lines(ui_buf)
    assert.has_string(result, "=> Hello, world!")
  end)

  it("stays on the websocket response when streaming updates", function()
    local DB = require("kulala.db")
    local buf = vim.api.nvim_get_current_buf()
    local db = DB.global_update()

    db.responses = {
      ---@diagnostic disable-next-line: missing-fields
      {
        id = buf .. ":1",
        status = true,
        code = 0,
        response_code = 200,
        duration = 0,
        time = 0,
        url = "http://example.com",
        method = "GET",
        line = 1,
        buf = buf,
        buf_name = "test.http",
        name = "Prior",
        body = "prior",
        headers = "",
      },
    }
    db.current_response_pos = 1
    db.previous_response_pos = 0

    kulala.run()
    wait_for_requests(1)

    db.current_response_pos = 1

    system.write_to("stdout", '{"type":"message","data":"Hello, world!"}\n')
    wait_for_requests(2)

    result = h.get_buf_lines(ui_buf):to_string()
    assert.has_string(result, "Request: 2/2")
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
    assert.is_truthy(system.log[2][2]:find("Sending"))

    result = h.get_buf_lines(ui_buf)
  end)

  it("shows errors", function()
    kulala_config.options.default_view = "verbose"

    kulala.run()
    wait_for_requests(1)

    system.write_to("stderr", "Error: Connection closed\n")
    wait_for_requests(2)

    result = h.get_buf_lines(ui_buf):to_string()
    assert.has_string(result, "Code: -1")
    assert.has_string(result, "Connection closed")
  end)

  it("closes connection", function()
    kulala.run()
    wait_for_requests(1)

    vim.api.nvim_set_current_win(h.get_kulala_win())
    ws.close()

    wait_for_requests(3)
    assert.is_true(vim.iter(system.log):any(function(e)
      return e[1] == "write" and e[2]:find('"op":"close"')
    end))

    result = h.get_buf_lines(ui_buf)
    assert.has_string(result, "Code: -1")
    assert.has_string(result, "Connection closed")
  end)
end)
