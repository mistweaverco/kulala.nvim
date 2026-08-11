local FS = require("kulala.utils.fs")
local placement = require("kulala.ui.image.placement")
local terminal = require("kulala.ui.image.terminal")

local M = {}

local setup_done = false

local function ensure_setup()
  if setup_done then return end
  setup_done = true
  vim.api.nvim_create_autocmd("ExitPre", {
    group = vim.api.nvim_create_augroup("kulala.image", { clear = true }),
    callback = function()
      placement.clean()
    end,
  })
end

---@return boolean
function M.supports()
  return terminal.supports()
end

---@return "kitty"|"iterm2"|nil
function M.protocol()
  return terminal.protocol()
end

---Ensure path is a PNG file (convert via kulala-core when needed).
---@param path string
---@param binary? { content?: string, mediaType?: string }
---@return string|nil png_path
---@return string|nil err
local function ensure_png(path, binary)
  local lower = path:lower()
  if lower:match("%.png$") then return path end

  -- Prefer in-memory convert from stored base64 when available.
  local content = binary and binary.content
  local media_type = binary and binary.mediaType
  if type(content) ~= "string" or content == "" then
    local fd = io.open(path, "rb")
    if not fd then return nil, "cannot read image file" end
    local bytes = fd:read("*a")
    fd:close()
    if type(bytes) ~= "string" then return nil, "cannot read image file" end
    content = vim.base64.encode(bytes)
  end

  local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")
  local ok, converted, err = pcall(KULALA_CORE.convert_image, {
    content = content,
    mediaType = media_type,
    target = "png",
  })
  if not ok then return nil, tostring(converted) end
  if not converted then return nil, err or "convert_image failed" end

  local png_path = vim.fn.tempname() .. ".png"
  local decoded = vim.base64.decode(converted.content)
  if not FS.write_file(png_path, decoded, false, true) then return nil, "failed to write converted PNG" end
  return png_path
end

---@param buf number
function M.clear(buf)
  ensure_setup()
  placement.clean(buf)
end

---Show an image in the given buffer using Kitty graphics or iTerm2 OSC 1337.
---@param buf number
---@param path string
---@param opts? { binary?: table, pos?: {[1]:number,[2]:number}, max_width?: number, max_height?: number }
---@return boolean shown
function M.show(buf, path, opts)
  ensure_setup()
  opts = opts or {}
  if not vim.api.nvim_buf_is_valid(buf) then return false end
  if type(path) ~= "string" or path == "" or vim.fn.filereadable(path) == 0 then return false end

  M.clear(buf)

  if not M.supports() then return false end

  local protocol = M.protocol()
  if protocol == "iterm2" then
    local fd = io.open(path, "rb")
    if not fd then return false end
    local bytes = fd:read("*a")
    fd:close()
    if type(bytes) ~= "string" then return false end
    terminal.iterm2_image(vim.base64.encode(bytes), #bytes)
    return true
  end

  if protocol ~= "kitty" then return false end

  local png_path = ensure_png(path, opts.binary)
  if not png_path then return false end

  local line_count = vim.api.nvim_buf_line_count(buf)
  placement.new(buf, png_path, {
    pos = opts.pos or { math.max(1, line_count), 0 },
    auto_resize = true,
    max_width = opts.max_width,
    max_height = opts.max_height,
  })
  return true
end

return M
