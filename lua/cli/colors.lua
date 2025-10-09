local M = {}

M.get_hl_ansi = function(hl_group, str)
  hl_group = hl_group or "Grey"
  if _G.arg.mono then return str end

  local hl, r, g, b
  local esc = string.char(27)
  local reset = esc .. "[0m"

  hl = vim.api.nvim_get_color_by_name(hl_group)
  hl = hl ~= -1 and hl or vim.api.nvim_get_hl(0, { name = hl_group, link = false })["fg"]
  if not hl then return reset end

  r = math.floor(hl / (256 * 256))
  g = math.floor(hl / 256) % 256
  b = hl % 256

  return ("%s[38;2;%s;%s;%sm%s%s"):format(esc, r, g, b, str, reset)
end

M.print = function(str, hl_group)
  io.write(M.get_hl_ansi(hl_group, str) .. "\n")
end

M.print_buf = function(buf)
  --TODO: optimize by reading end line and end column

  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local char, char_i, color_char
  local extmarks_hl, treesitter_hl, syntax_hl

  for l, line in ipairs(lines) do
    if _G.arg.mono then
      io.write(line)
      goto continue
    end

    for c = 0, #line do
      char = line:sub(c, c)
      char_i = vim.inspect_pos(buf, l - 1, c)

      extmarks_hl = char_i.extmarks[1] and char_i.extmarks[1].opts.hl_group
      treesitter_hl = not extmarks_hl and char_i.treesitter and char_i.treesitter[1] and char_i.treesitter[1].hl_group
      syntax_hl = not treesitter_hl and char_i.syntax and char_i.syntax[1] and char_i.syntax[1].hl_group

      color_char = M.get_hl_ansi(extmarks_hl or treesitter_hl or syntax_hl, char)

      io.write(color_char)
    end

    ::continue::
    io.write("\n")
  end
end

return M
