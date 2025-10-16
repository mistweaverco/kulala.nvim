-- Formatter using kulala-fmt (https://www.npmjs.com/package/kulala-fmt)

local Async = require("kulala.utils.async")
local Db = require("kulala.db")
local Float = require("kulala.ui.float")
local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

local FMT_DIR = Fs.get_plugin_root_dir() .. "/../../fmt"
local FMT_BUILD_DIR = Fs.join_paths(Fs.get_plugin_tmp_dir(), "fmt") -- .cache/nvim/kulala/fmt

local NPM_BIN = vim.fn.exepath("npm")
local FMT_CMD = { NPM_BIN, "exec", "--prefix", FMT_BUILD_DIR, "--", "kulala-fmt" }

M.check_formatter = function(callback, wait)
  if vim.g.kulala_fmt_installing then return false end

  local function get_build_ver()
    local package = Fs.read_json(FMT_DIR .. "/package.json")
    return package and package.version or ""
  end

  Db.session.fmt_build_ver_repo = Db.session.fmt_build_ver_repo or get_build_ver()
  if Db.settings.fmt_build_ver_local == Db.session.fmt_build_ver_repo then return true end

  Logger.warn("Updating formatter...please wait")
  local progress = Float.create_progress_float("Updating formatter...")

  local co, cmd_install, cmd_build
  co = coroutine.create(function()
    vim.g.kulala_fmt_installing = true

    Fs.copy_dir(FMT_DIR, FMT_BUILD_DIR)

    cmd_install = Shell.run(
      { NPM_BIN, "install", "--prefix", FMT_BUILD_DIR },
      { err_msg = "Formatter install failed: ", on_error = progress.hide },
      function()
        Async.co_resume(co)
      end
    )
    Async.co_yield(co)

    cmd_build = Shell.run(
      { NPM_BIN, "run", "build", "--prefix", FMT_BUILD_DIR },
      { err_msg = "Formatter build failed: ", on_error = progress.hide },
      function()
        Async.co_resume(co)
      end
    )
    Async.co_yield(co)

    Async.co_wrap(co, function()
      Db.settings:write { fmt_build_ver_local = Db.session.fmt_build_ver_repo }
      vim.g.kulala_fmt_installing = false
    end)

    _ = callback and callback()
    progress.hide()
  end)

  Async.co_resume(co)

  _ = wait and cmd_install:wait()
  if not cmd_build then return false end -- close coutine if install failed ?

  _ = wait and cmd_build:wait()

  return false
end

M.format = function(text)
  --INFO: deprecated

  text = type(text) == "table" and text or { text }
  text = table.concat(text, "\n") .. "\n"

  local cmd = vim.list_extend(vim.deepcopy(FMT_CMD), { "format", "--stdin" })
  local result = Shell.run(cmd, { stdin = text, err_msg = "Formatter error: " })

  result = result and result:wait() or {}

  return result.code == 0 and result.stdout or text
end

---Converts from Postman/OpenAPI/Bruno to HTTP
---@param from string|nil "postman"|"openapi"|"bruno"
---@param path string|nil Path to the file to convert
M.convert = function(from, path)
  local status, result = xpcall(M.check_formatter, debug.traceback, nil, true)
  if not status then return Logger.error(("Errors updating formatter: %s"):format(result), 1, { report = true }) end

  path = type(path) == "string" and path or vim.fn.expand("%:p")

  local ext = vim.fn.fnamemodify(path, ":e")
  local ft = ext:match("ya?ml") and "yaml" or ext:match("bruno") and "bruno"
  local cmd = vim.list_extend(vim.deepcopy(FMT_CMD), { "convert" })

  if ft == "bruno" then
    from = "bruno"
    path = vim.fs.dirname(path)
  elseif ft == "yaml" then
    from = "openapi"
  end

  from = type(from) == "string" and from or "postman"

  vim.list_extend(cmd, { "--from", from, path })
  local result = Shell.run(cmd, { err_msg = "Formatter error: " })

  result = result and result:wait()
  if not result or result.stdout == "" then return end

  local out = result.stdout:gsub("\n", "")
  Logger.info(out)

  local file = table.remove(vim.split(out, " "))
  _ = vim.fn.filereadable(file) == 1 and vim.cmd.edit(file)
end

return M
