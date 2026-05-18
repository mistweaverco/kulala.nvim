local Logger = require("kulala.logger")
local M = {}

local function redirect_script()
  return [[
    <!DOCTYPE html>
    <html>
    <body>
      <p>Processing authentication...</p>
      <script>
        const fragment = window.location.hash.substring(1);

        if (fragment && fragment.includes('access_token=')) {
          window.location.href = '\/?' + fragment;
        } else {
          document.body.innerHTML = '<p>No access token found in URL fragment.</p>';
        }
      </script>
    </body>
    </html>
  ]]
end

M.server = {
  run = function(self, host, port, on_request)
    host = host or "127.0.0.1"
    port = tonumber(port) or 8080

    local server = vim.uv.new_tcp() or {}
    local status, err = server:bind(host, port)

    if not status then
      return Logger.warn(("TCP server: failed to bind on %s:%s (%s)"):format(host, port, err or ""))
    end

    status, err = server:listen(128, function(listen_err)
      if listen_err then return Logger.error("TCP server: failed to accept connection: " .. listen_err) end

      local client = vim.uv.new_tcp() or {}
      server:accept(client)

      client:read_start(function(read_err, chunk)
        if read_err then return Logger.error("TCP server: failed to process request: " .. read_err) end
        if not chunk then return self:stop(client) end

        local response = ""
        local result

        if chunk:match("GET / HTTP") then
          response = redirect_script()
        elseif chunk:match("GET /[^%?]*%?(.+)") then
          result = on_request(chunk:match("GET /[^%?]*%?(.+) HTTP"))
          response = result or "OK"
        end

        client:write("HTTP/1.1 200 OK\r\n\r\n" .. response .. "\n")
        self:stop(client)

        if result then self:stop(server) end
      end)
    end)

    if not status then
      return Logger.warn(("TCP server failed to listen on %s:%s (%s)"):format(host, port, err or ""))
    end

    local socket = server:getsockname()
    if socket then
      Logger.info("Server listening for code/token on " .. socket.ip .. ":" .. socket.port)
    else
      return Logger.warn(("TCP server failed to get socket on %s:%s"):format(host, port))
    end

    self.server = server
    -- vim.uv.run() -- not needed, libuv loop is already running in Neovim

    return self
  end,

  stop = function(self, tcp)
    tcp = tcp or self.server

    return pcall(function()
      if tcp.shutdown then tcp:shutdown() end
      if tcp.close then tcp:close() end
    end)
  end,
}

M.server = setmetatable(M.server, {
  __call = function(self, ...)
    return self:run(...)
  end,
})

---@class RequestParams: ShellOpts
---@field method string|nil -- HTTP method (default: "GET")
---@field headers table<string, string>|nil -- HTTP headers (default: {})
---@field body string|nil -- HTTP body (default: "")

---@param url string -- URL to request
---@param params RequestParams|nil -- Request parameters
---@param on_exit fun(system: vim.SystemCompleted)|nil -- Callback on exit
---@return vim.SystemObj|vim.SystemCompleted|nil
local function request(url, params, on_exit)
  params = vim.tbl_deep_extend("keep", params or {}, {
    method = "GET",
    headers = {},
    body = "",
    sync = true,
    err_msg = "Request error",
    abort_on_stderr = true,
  })

  local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")

  local result, err = KULALA_CORE.http_request {
    url = url,
    method = params.method,
    headers = params.headers,
    body = params.body,
    timeoutSec = 30,
  }

  local system = {
    code = err and 1 or 0,
    stdout = result and result.body or "",
    stderr = err or "",
  }

  if on_exit then
    vim.schedule(function()
      on_exit(system)
    end)
    return system
  end
  return system
end

M.client = {
  request = request,
}

return M
