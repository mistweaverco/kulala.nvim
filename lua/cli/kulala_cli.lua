#!/usr/bin/env -S nvim --headless -l

--TODO: make windows compatible: paths and install scripts

--# selene: allow(unscoped_variables)
--# selene: allow(unused_variable)
--# selene: allow(undefined_variable)

local kulala_path
local default_opts = {}

local args = {}
local opts = {}

-- Helper function to parse a string value to appropriate Lua type
local function parse_value(str)
  if str == "true" then return true end
  if str == "false" then return false end
  if str == "nil" then return nil end
  local num = tonumber(str)
  if num then return num end
  return str
end

-- Helper function to set a nested table value using dot-separated path
local function set_nested_value(tbl, path, value)
  local keys = vim.split(path, ".", { plain = true })
  local current = tbl
  for i = 1, #keys - 1 do
    current[keys[i]] = current[keys[i]] or {}
    current = current[keys[i]]
  end
  current[keys[#keys]] = value
end

-- Parse --set key=value arguments into a nested table
local function parse_inline_overrides(overrides)
  local result = {}
  for _, override in ipairs(overrides or {}) do
    local key, value = override:match("^(.-)=(.*)$")
    if key and key ~= "" then set_nested_value(result, key, parse_value(value)) end
  end
  return result
end

-- Load a config file safely, returning empty table on failure
local function load_config_file(path, silent)
  if not path then return {} end
  local ok, config = pcall(loadfile, path)
  if ok and config then
    local success, result = pcall(config)
    if success and type(result) == "table" then
      return result
    elseif not silent then
      vim.print("Warning: Config file returned invalid data: " .. path)
    end
  elseif not silent and vim.fn.filereadable(path) == 1 then
    vim.print("Warning: Failed to load config file: " .. path)
  end
  return {}
end

-- Load and merge configs from all sources with proper priority
local function load_config()
  -- Priority (lowest to highest):
  -- 1. Default CLI config (lua/cli/config.lua)
  -- 2. User config (~/.config/nvim/kulala/cli.lua)
  -- 3. Project-local config (.kulala-cli.lua in CWD)
  -- 4. CLI-specified config (-c option)
  -- 5. Inline overrides (--set option)

  local configs = {}

  -- 1. Default CLI config (already loaded in init())
  table.insert(configs, default_opts)

  -- 2. User config
  local user_config_path = vim.fn.stdpath("config") .. "/kulala/cli.lua"
  table.insert(configs, load_config_file(user_config_path, true))

  -- 3. Project-local config
  local project_config_path = vim.fn.getcwd() .. "/.kulala-cli.lua"
  table.insert(configs, load_config_file(project_config_path, true))

  -- 4. CLI-specified config (-c option)
  if args.config then
    local cli_config = load_config_file(args.config, false)
    if vim.tbl_isempty(cli_config) and vim.fn.filereadable(args.config) == 0 then
      vim.print("Error: Config file not found: " .. args.config)
      os.exit(1)
    end
    table.insert(configs, cli_config)
  end

  -- 5. Inline overrides (--set option)
  if args.set and #args.set > 0 then table.insert(configs, parse_inline_overrides(args.set)) end

  -- Merge all configs in order
  opts = {}
  for _, cfg in ipairs(configs) do
    opts = vim.tbl_deep_extend("force", opts, cfg)
  end
end

local setup = function()
  pcall(require, "nvim-treesitter")

  Config = require("kulala.config")
  Globals = require("kulala.globals")
  Cmd = require("kulala.cmd")
  Db = require("kulala.db")
  Parser = require("kulala.parser.document")
  Export = require("kulala.cmd.export")
  Fmt = require("kulala.formatter.fmt")
  Colors = require("cli.colors")
  Ui = require("kulala.ui")
  UI_utils = require("kulala.ui.utils")
  Logger = require("kulala.logger")

  Request_timout = 10000
  vim.o.columns = 120

  Config = Config.setup(vim.tbl_deep_extend("force", opts, {
    default_env = args.env,
    halt_on_error = args.halt,
    ui = {
      display_mode = "float",
      default_view = args.view,
    },
  }))

  require("kulala.parser.scripts.engines.javascript").install_dependencies(true)
  vim.g.kulala_cli = true
end

local function init()
  local script_path = debug.getinfo(1).source:sub(2)
  kulala_path = vim.fs.root(script_path, ".gitignore")

  if not kulala_path then
    vim.print("Kulala is not found. Please install Kulala.nvim")
    os.exit(1)
  end

  vim.opt.rtp:prepend(kulala_path)

  -- Load default CLI config (will be merged with other sources in load_config())
  local _, config = pcall(loadfile, kulala_path .. "/lua/cli/config.lua")
  default_opts = config and config() or {}

  local plugins = vim.fn.stdpath("data")
  local treesitter_path = vim.fs.find("nvim-treesitter", { path = plugins, type = "directory", limit = 1 })[1]

  _ = treesitter_path and vim.opt.rtp:prepend(treesitter_path)
end

local function get_args()
  Argparse = require("cli.argparse")

  local parser = Argparse() {
    name = "Kulala CLI",
    description = "Kulala REST client CLI",
    epilog = "For more info, see https://neovim.getkulala.net\n",
  }

  parser:argument("input", "Path to folder or HTTP file/s"):args("+")
  parser:option("-n --name", "Filter requests by name"):args("*")
  parser:option("-l --line", "Filter requests by line #"):convert(tonumber):args("*")
  parser:option("-e --env", "Environment")
  parser:option("-s --sub", "Substitute variable"):args("*")
  parser:option("-v --view", "Response view"):choices {
    "body",
    "headers",
    "headers_body",
    "verbose",
    "script_output",
    "report",
  }

  parser:flag("--list", "List requests in HTTP file")
  parser:flag("--halt", "Halt on error")
  parser:flag("-m --mono", "Monochrome output")

  -- Config override options
  parser:option("-c --config", "Path to custom config file")
  parser:option("--set", "Override config value (format: key=value or nested.key=value)"):args("*")

  parser:require_command(false)
  parser:command("export"):summary("Export HTTP file or folder to Postman collection")
  parser:command("import"):summary("Import HTTP files from Postman/OpenAPI/Bruno")

  parser:option("-f --from", "Import from"):choices {
    "postman",
    "openapi",
    "bruno",
  }

  args = parser:parse(_G.arg)

  args.name = args.name or {}
  args.line = args.line or {}

  if vim.tbl_contains({ "import", "export" }, args.input[1]) then args.command = table.remove(args.input, 1) end

  _G.arg = args
end

local function get_kulala_buf()
  return vim.fn.bufnr(Globals.UI_ID)
end

local function print_requests(file, requests)
  local tbl = UI_utils.Ptable:new {
    header = { "Line", "Name", "URL" },
    widths = { 5, 40, 50 },
  }

  Colors.print("File: " .. file, Config.ui.report.headersHighlight)
  Colors.print(tbl:get_headers(), Config.ui.report.headersHighlight)

  vim.iter(requests):each(function(request)
    Colors.print(tbl:get_row({
      request.show_icon_line_number,
      request.name,
      request.method .. " " .. request.url,
    }, 1))
  end)

  io.write("\n")

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

  io.write("\n\n")
  Colors.print_buf(ui_buf)
end

local get_requests = function()
  local requests = Parser.get_document()

  -- Filter out requests without URL (variable-only blocks)
  requests = vim
    .iter(requests)
    :filter(function(request)
      return request.url and #request.url > 0
    end)
    :totable()

  if args.list or #args.name + #args.line == 0 then return requests end

  requests = vim
    .iter(requests)
    :filter(function(request)
      return vim.tbl_contains(args.name, request.name) or vim.tbl_contains(args.line, request.show_icon_line_number)
    end)
    :totable()

  return requests
end

local function substitute_variables(requests, subs)
  local vars = {}

  for _, sub in ipairs(subs) do
    local key, value = sub:match("^(.-)=(.+)$")
    if key and value then vars[key] = value end
  end

  vim.iter(requests):each(function(request)
    request.shared.variables = vim.tbl_extend("force", request.shared.variables, vars)
  end)

  return requests
end

local function is_last()
  return Cmd.queue.done == Cmd.queue.total
end

local function run_file(file)
  if not io.open(file) then return Logger.error("File not found: " .. file) end
  vim.cmd.edit(file)

  local buf = vim.fn.bufnr(file)
  Db.set_current_buffer(buf)

  local requests = get_requests()
  if #requests == 0 then return Logger.error("No requests found in " .. file) end

  if args.list then return print_requests(file, requests) end

  if args.sub and #args.sub > 0 then requests = substitute_variables(requests, args.sub) end

  local db = Db.global_update()
  local processing = true
  local status = true

  Cmd.run_parser(requests, 0, function()
    io.write("*")

    db.current_response_pos = #db.responses
    status = status and db.responses[#db.responses].status

    if Config.ui.default_view == "report" and not is_last() then return end
    print_response()

    if is_last() then processing = false end
  end)

  vim.wait(Request_timout * #requests, function()
    io.write(".")
    return not processing
  end)

  io.write("\n")

  local msg = status and { "Status: OK", Config.ui.report.successHighlight }
    or { "Status: FAIL", Config.ui.report.errorHighlight }
  Colors.print(unpack(msg))

  vim.api.nvim_buf_delete(buf, { force = true })
  db.responses = {}

  return status
end

local function run_command()
  if #args.input == 0 then return Logger.error("No input file specified") end

  _ = args.command == "export" and Export.export_requests(args.input[1])
  _ = args.command == "import" and Fmt.convert(args.from, args.input[1])

  return true
end

local function run()
  local status = true

  if args.command then return run_command() end

  vim.iter(args.input):each(function(path)
    path = vim.fs.normalize(vim.fs.abspath(path))

    if vim.fn.isdirectory(path) == 1 then
      local files = vim.fn.glob(path .. "/*.http", false, true)
      if #files == 0 then return Logger.error("No HTTP files found in " .. path) end

      for _, file in ipairs(files) do
        status = status and run_file(file)
      end
    else
      status = status and run_file(path)
    end
  end)

  return status
end

local function main()
  init()
  get_args()
  load_config()
  setup()

  local result = run()

  vim.g.kulala_cli = nil
  return result
end

io.write("\n")
os.exit(main() and 0 or 1)
