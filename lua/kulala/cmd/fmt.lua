local Async = require("kulala.utils.async")
local Db = require("kulala.db")
local Float = require("kulala.ui.float")
local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local Shell = require("kulala.cmd.shell_utils")

local M = {}

local FMT_DIR = Fs.get_plugin_root_dir() .. "/../../fmt"
local FMT_BUILD_DIR = Fs.join_paths(Fs.get_plugin_tmp_dir(), "fmt")

local NPM_BIN = vim.fn.exepath("npm")
local FMT_BIN = FMT_BUILD_DIR .. "/dist/cli.cjs"

M.check_formatter = function(callback)
  if vim.g.kulala_fmt_installing then return false end

  local function get_build_ver()
    local package = Fs.read_json(FMT_DIR .. "/package.json")
    return package and package.version or ""
  end

  Db.session.fmt_build_ver_repo = Db.session.fmt_build_ver_repo or get_build_ver()
  if Db.settings.fmt_build_ver_local == Db.session.fmt_build_ver_repo then return true end

  local progress = Float.create_progress_float("Updating formatter...")

  local co
  co = coroutine.create(function()
    vim.g.kulala_fmt_installing = true

    Fs.copy_dir(FMT_DIR, FMT_BUILD_DIR)

    Shell.run(
      { NPM_BIN, "install", "--prefix", FMT_BUILD_DIR },
      { err_msg = "Formatter install failed: ", on_error = progress.hide },
      function()
        Async.co_resume(co)
      end
    )
    Async.co_yield(co)

    Shell.run(
      { NPM_BIN, "run", "build", "--prefix", FMT_BUILD_DIR },
      { err_msg = "Formatter build failed: ", on_error = progress.hide },
      function()
        Async.co_resume(co)
      end
    )
    Async.co_yield(co)

    Db.settings:write({ fmt_build_ver_local = Db.session.fmt_build_ver_repo })
    vim.g.kulala_fmt_installing = false

    callback()
    progress.hide()
  end)

  Async.co_resume(co)

  return false
end

M.format = function(text)
  text = type(text) == "table" and text or { text }
  text = table.concat(text, "\n") .. "\n"

  local result = Shell.run({ FMT_BIN, "format", "--stdin" }, { stdin = text, err_msg = "Formatter error: " })
  result = result and result:wait()

  return result and result.stdout
end

M.convert = function()
  local path = vim.fn.expand("%:p")
  local ft = vim.bo.filetype
  local cmd = { FMT_BIN, "convert" }

  if ft == "bruno" then
    vim.list_extend(cmd, { "--from", "bruno" })
    path = vim.fs.dirname(path)
  end

  table.insert(cmd, path)

  local result = Shell.run(cmd, { err_msg = "Formatter error: " })

  result = result and result:wait()
  if not result or result.stdout == "" then return end

  local out = result.stdout:gsub("\n", "")
  Logger.info(out)

  local file = table.remove(vim.split(out, " "))
  _ = vim.fn.filereadable(file) == 1 and vim.cmd.edit(file)
end

-- kulala-fmt convert --from openapi openapi.yaml
-- kulala-fmt convert --from postman postman.json
-- kulala-fmt convert --from bruno path/to/bruno/collection

return M
