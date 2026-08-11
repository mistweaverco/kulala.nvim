local terminal = require("kulala.ui.image.terminal")

local M = {}

local dims = {} ---@type table<string, {width: number, height: number}>

---@param file string
---@return {width: number, height: number}
function M.dim(file)
  file = vim.fs.normalize(file)
  if dims[file] then return dims[file] end
  local fd = assert(io.open(file, "rb"), "Failed to open file: " .. file)
  local header = fd:read(24)
  fd:close()
  assert(header and header:sub(1, 8) == "\137PNG\r\n\26\n", "Not a valid PNG file: " .. file)
  local width = header:byte(17) * 16777216 + header:byte(18) * 65536 + header:byte(19) * 256 + header:byte(20)
  local height = header:byte(21) * 16777216 + header:byte(22) * 65536 + header:byte(23) * 256 + header:byte(24)
  dims[file] = { width = width, height = height }
  return dims[file]
end

---@param size {width: number, height: number}
---@return {width: number, height: number}
function M.norm(size)
  return {
    width = math.max(1, math.ceil(size.width)),
    height = math.max(1, math.ceil(size.height)),
  }
end

---@param size {width: number, height: number}
---@return {width: number, height: number}
function M.pixels_to_cells(size)
  local term = terminal.size()
  return M.norm {
    width = size.width / term.cell_width,
    height = size.height / term.cell_height,
  }
end

---@param file string
---@param cells {width: number, height: number}
---@return {width: number, height: number}
function M.fit(file, cells)
  local img_cells = M.pixels_to_cells(M.dim(file))
  local ret = vim.deepcopy(cells)
  if img_cells.width <= cells.width and img_cells.height <= cells.height then return img_cells end
  ret.width = math.min(cells.width, img_cells.width)
  ret.height = math.min(cells.height, img_cells.height)

  local scale = ret.width / ret.height
  local img_scale = img_cells.width / img_cells.height
  local fit_height = math.floor(ret.width / img_scale + 0.5)
  local fit_width = math.floor(ret.height * img_scale + 0.5)

  if ret.height ~= fit_height and ret.width ~= fit_width then
    if img_scale > scale then
      ret.height = fit_height
    else
      ret.width = fit_width
    end
  end
  return M.norm(ret)
end

---@param data string
---@return string
function M.base64(data)
  return vim.base64.encode(data)
end

return M
