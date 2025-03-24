local M = {}
M.send_json_to_lsp = function(client_name, method, command, json_data)
  local clients = vim.lsp.get_clients({ bufnr = vim.api.nvim_get_current_buf() })

  if not clients then return end

  local target_client = nil
  for _, client in ipairs(clients) do
    if client.name == client_name then
      target_client = client
      break
    end
  end

  if not target_client then return end

  local params = {
    command = command,
    arguments = { json_data },
  }

  target_client.request(method, params, function(err)
    if err then vim.notify(string.format("Error sending JSON: %s", err.message), vim.log.levels.ERROR) end
  end)
end

M.add_request_variables = function(filepath, name, headers, body)
  -- try to json decode the body
  local status, json_body = pcall(vim.json.decode, body, { object = true, array = true })
  if not status or json_body == nil then return end
  M.send_json_to_lsp("kulala_ls", "workspace/executeCommand", "addRequestVariables", {
    doc = filepath,
    name = name,
    headers = headers,
    body = json_body,
  })
end

return M
