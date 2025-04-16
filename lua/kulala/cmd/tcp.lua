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
    port = tonumber(port) or 80

    local server = vim.uv.new_tcp() or {}
    local status, err = pcall(server.bind, server, host, port)
    if not status then return Logger.error("Failed to start TCP server: " .. err) end

    Logger.info("Server listening for code/token on " .. host .. ":" .. port)

    server:listen(128, function(err)
      if err then return Logger.error("Failed to process request: " .. err) end

      local client = vim.uv.new_tcp() or {}
      server:accept(client)

      client:read_start(function(err, chunk)
        if err then return Logger.error("Failed to read server response: " .. err) end
        ---@diagnostic disable-next-line: redundant-return-value
        if not chunk then return self:stop(client) end

        local response = ""
        local result

        if chunk:match("GET / HTTP") then
          response = redirect_script()
        elseif chunk:match("GET /%?") then
          result = on_request(chunk:match("GET /%?(.+) HTTP"))
          response = result or "OK"
        end

        client:write("HTTP/1.1 200 OKn\r\n\r\n" .. response .. "\n")
        self:stop(client)

        if result then self:stop(server) end
      end)
    end)

    vim.uv.run()

    return self
  end,

  stop = function(_, tcp)
    pcall(function()
      tcp:shutdown()
      tcp:close()
    end)
  end,
}

M.server = setmetatable(M.server, {
  __call = function(self, ...)
    self:run(...)
  end,
})

return M
