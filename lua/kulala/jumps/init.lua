local Ts = vim.treesitter

local M = {}

-- Function to find all "request" nodes in the tree
local function find_all_request_nodes(node)
  local request_nodes = {}

  local function recursive_search(node)
    if not node then return end

    for child in node:iter_children() do
      if child:type() == "request" then
        table.insert(request_nodes, child)
      end
      recursive_search(child)
    end
  end

  recursive_search(node)
  return request_nodes
end

-- Function to move to the next "request" node
M.jump_next = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = Ts.get_parser(bufnr)
  local tree = parser:parse()[1]
  local root = tree:root()

  local request_nodes = find_all_request_nodes(root)

  -- Get the current cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_row = cursor[1] - 1
  local current_col = cursor[2]

  for _, node in ipairs(request_nodes) do
    local start_row, start_col, _, _ = node:range()
    if start_row > current_row or (start_row == current_row and start_col > current_col) then
      vim.api.nvim_win_set_cursor(0, {start_row + 1, start_col})
      return
    end
  end

  print("No next 'request' node found")
end

-- Function to move to the previous "request" node
M.jump_prev = function()
  local bufnr = vim.api.nvim_get_current_buf()
  local parser = Ts.get_parser(bufnr)
  local tree = parser:parse()[1]
  local root = tree:root()

  local request_nodes = find_all_request_nodes(root)

  -- Get the current cursor position
  local cursor = vim.api.nvim_win_get_cursor(0)
  local current_row = cursor[1] - 1
  local current_col = cursor[2]

  for i = #request_nodes, 1, -1 do
    local node = request_nodes[i]
    local start_row, start_col, _, _ = node:range()
    if start_row < current_row or (start_row == current_row and start_col < current_col) then
      vim.api.nvim_win_set_cursor(0, {start_row + 1, start_col})
      return
    end
  end

  print("No previous 'request' node found")
end




return M
