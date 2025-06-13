local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

M.format = function(xml_string, opts)
  opts = vim.tbl_deep_extend("keep", opts or {}, {
    verbose = true,
  })

  local system_arg_limit = 1000

  local path = require("kulala.config").get().contenttypes["application/xml"]
  path = path and path.formatter and path.formatter[1] or vim.fn.exepath("xmllint")

  if vim.fn.executable(path) == 0 then
    _ = opts.versbose and Logger.warn("jq is not installed. JSON written unformatted.")
    return xml_string
  end

  local cmd = { path, "--format" }

  local temp_file
  if #xml_string > system_arg_limit then
    temp_file = os.tmpname()
    require("kulala.utils.fs").write_file(temp_file, xml_string)

    vim.list_extend(cmd, { temp_file, "--output", temp_file })
  else
    vim.list_extend(cmd, { "-" })
  end

  local result = Shell.run(cmd, {
    sync = true,
    stdin = not temp_file and xml_string or nil,
    err_msg = "Failed to format XML",
    abort_on_stderr = true,
  })

  if not result then return xml_string end
  _ = temp_file and os.remove(temp_file)

  return result.stdout
end

return M
