#!/usr/bin/env -S nvim --headless -l

_, LOG = pcall(require, "log")

--TODO: install script: download nvim.appimage and install kulala

--# selene: allow(unscoped_variables)
--# selene: allow(unused_variable)
--# selene: allow(undefined_variable)

local kulala_path

local args = {}
local opts = {}

local setup = function()
  pcall(require, "nvim-treesitter")

  Config = require("kulala.config")
  Globals = require("kulala.globals")
  Cmd = require("kulala.cmd")
  Db = require("kulala.db")
  Parser = require("kulala.parser.document")
  Colors = require("cli.colors")
  Ui = require("kulala.ui")
  UI_utils = require("kulala.ui.utils")
  Logger = require("kulala.logger")

  Request_timout = 10000
  vim.o.columns = 160

  Config = Config.setup(vim.tbl_deep_extend("force", opts, {
    default_env = args.env,
    halt_on_error = args.halt,
    ui = {
      display_mode = "float",
      default_view = args.view,
    },
  }))
end

local function init()
  local script_path = debug.getinfo(1).source:sub(2)
  kulala_path = vim.fs.root(script_path, "kulala.nvim") .. "/kulala.nvim"

  local plugins = vim.fn.stdpath("data")
  local treesitter_path = vim.fs.find("nvim-treesitter", { path = plugins, type = "directory" })[1]

  if not kulala_path then
    vim.print("Kulala is nout found. Please install Kulala.nvim")
    os.exit(1)
  end

  local _, config = pcall(loadfile, kulala_path .. "/lua/cli/config.lua")
  opts = config and config() or {}

  vim.opt.rtp:prepend(kulala_path)
  vim.opt.rtp:prepend(treesitter_path)
end

local function get_args()
  Argparse = require("cli.argparse")
  local parser = Argparse()({
    name = "Kulala CLI",
    description = "REST client CLI",
    epilog = "For more info, see https://neovim.getkulala.net\n",
  })

  parser:argument("input", "Input HTTP file")
  parser:command("list"):summary("List all requests in the HTTP file")

  parser:require_command(false)
  parser:command_target("command")

  parser:mutex(
    parser:option("-n --name", "Run request name"):args("*"),
    parser:option("-l --line", "Run request at line"):convert(tonumber):args("*")
  )

  parser:option("-e --env", "Environment")
  -- parser:option("-f --env-file", "Environment file", "http-client.env.json")
  -- parser:option("-p --private", "Private environment file", "http-client.private.env.json")
  parser:option("-v --view", "Response view"):choices({
    "body",
    "headers",
    "headers_body",
    "verbose",
    "script_output",
    "report",
  })

  parser:flag("-h --halt", "Halt on error")
  parser:option("-c --color", "Color output", "true"):choices({ "true", "false" })

  args = parser:parse(_G.arg)
  _G.arg = args

  args.name = args.name or {}
  args.line = args.line or {}
end

local function get_kulala_buf()
  return vim.fn.bufnr(Globals.UI_ID)
end

local function print_requests(requests)
  local tbl = UI_utils.Ptable:new({
    header = { "Line", "Name", "URL" },
    widths = { 5, 40, 50 },
  })

  Colors.print(tbl:get_headers(), "Cyan")
  Logger.info("\n")

  vim.iter(requests):each(function(request)
    Colors.print(
      tbl:get_row({
        request.show_icon_line_number,
        request.name,
        request.method .. " " .. request.url,
      }, 1),
      "Grey"
    )
  end)

  return true
end

local function print_response()
  Ui.open_default_view()
  local ui_buf = get_kulala_buf()

  local filetype = vim.bo[ui_buf].filetype:gsub("%.kulala_ui", "")
  pcall(vim.treesitter.start, ui_buf, filetype)
  vim.bo[ui_buf].syntax = "on"

  _ = Config.ui.default_view == "verbose" and vim.cmd("so " .. kulala_path .. "/syntax/kulala_verbose_result.vim")
  vim.cmd("redraw")

  Logger.info("\n\n")
  Colors.print_buf(ui_buf)
end

local get_requests = function()
  local variables, requests = Parser.get_document()
  if args.command == "list" or #args.name + #args.line == 0 then return requests, variables end

  requests = vim
    .iter(requests)
    :filter(function(request)
      return vim.tbl_contains(args.name, request.name) or vim.tbl_contains(args.line, request.show_icon_line_number)
    end)
    :totable()

  return requests, variables
end

local function run()
  local file = args.input
  if not io.open(file) then return Logger.error("File not found: " .. file) end

  vim.cmd.edit(file)

  local requests, variables = get_requests()
  if #requests == 0 then return Logger.error("No requests found in " .. file) end

  if args.command == "list" then return print_requests(requests) end

  local db = Db.global_update()
  local processing = true

  local function is_last()
    return #db.responses == #requests
  end

  local status = true
  Cmd.run_parser(requests, variables, nil, function()
    db.current_response_pos = #db.responses
    status = status and db.responses[#db.responses].status

    io.write("*")

    if Config.ui.default_view == "report" and not is_last() then return end
    print_response()

    if is_last() then processing = false end
  end)

  vim.wait(Request_timout * #requests, function()
    io.write(".")
    return not processing
  end)

  io.write("\n")

  local msg = status and { "Status: OK", "Green" } or { "Status: FAIL", "Red" }
  Colors.print(unpack(msg))

  return status
end

local function main()
  init()
  get_args()
  setup()

  return run()
end

os.exit(main() and 0 or 1)
