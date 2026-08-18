local M = {}

---@param item table|string|nil
---@return string|nil
local function path_from_snacks_item(item)
  if type(item) == "string" and item ~= "" then return item end
  if type(item) ~= "table" then return nil end
  local path = item.file or item.path or item.filename or item.text
  if type(path) == "string" and path ~= "" then return path end
  return nil
end

---@param selected string[]|nil
---@return string|nil
local function path_from_fzf_selected(selected)
  if type(selected) ~= "table" or not selected[1] then return nil end
  local ok, fzf = pcall(require, "fzf-lua")
  if ok and fzf.path and type(fzf.path.entry_to_file) == "function" then
    local parsed = fzf.path.entry_to_file(selected[1])
    if type(parsed) == "table" and type(parsed.path) == "string" and parsed.path ~= "" then return parsed.path end
  end
  local entry = selected[1]
  if type(entry) ~= "string" then return nil end
  return (entry:gsub("^[^%s]+%s+", ""))
end

---@param selection table|nil
---@return string|nil
local function path_from_telescope_selection(selection)
  if type(selection) ~= "table" then return nil end
  local path = selection.path or selection.filename or selection.value or selection[1]
  if type(path) == "string" and path ~= "" then return path end
  return nil
end

---@class kulala.ui.pick_file.opts
---@field prompt? string
---@field cwd? string

---Pick a filesystem file via snacks, fzf-lua, telescope, or `vim.fn.input`.
---@param opts kulala.ui.pick_file.opts|nil
---@param on_choice fun(path: string|nil)
function M.pick_file(opts, on_choice)
  opts = opts or {}
  local prompt = opts.prompt or "Select file"
  local cwd = opts.cwd

  local function finish(path)
    if type(path) == "string" then
      path = vim.fn.expand(path)
      if path == "" then path = nil end
    else
      path = nil
    end
    vim.schedule(function()
      on_choice(path)
    end)
  end

  local ok_snacks, snacks = pcall(require, "snacks")
  if ok_snacks and snacks.picker and type(snacks.picker.files) == "function" then
    snacks.picker.files {
      title = prompt,
      cwd = cwd,
      confirm = function(picker, item)
        picker:close()
        finish(path_from_snacks_item(item))
      end,
    }
    return
  end

  local ok_fzf, fzf = pcall(require, "fzf-lua")
  if ok_fzf and type(fzf.files) == "function" then
    fzf.files {
      prompt = prompt .. "> ",
      cwd = cwd,
      actions = {
        ["default"] = function(selected)
          finish(path_from_fzf_selected(selected))
        end,
      },
    }
    return
  end

  local ok_telescope = pcall(require, "telescope")
  if ok_telescope then
    local actions = require("telescope.actions")
    local action_state = require("telescope.actions.state")
    require("telescope.builtin").find_files {
      prompt_title = prompt,
      cwd = cwd,
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selection = action_state.get_selected_entry()
          actions.close(prompt_bufnr)
          finish(path_from_telescope_selection(selection))
        end)
        return true
      end,
    }
    return
  end

  local default = cwd and (cwd .. "/") or ""
  local path = vim.fn.input {
    prompt = prompt .. ": ",
    default = default,
    completion = "file",
  }
  finish(path)
end

return M
