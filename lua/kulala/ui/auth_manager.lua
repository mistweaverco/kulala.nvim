local has_telescope = pcall(require, "telescope")
local has_snacks, snacks_picker = pcall(require, "snacks.picker")

local Config = require("kulala.config")
local DB = require("kulala.db")
local Env = require("kulala.parser.env")
local Fs = require("kulala.utils.fs")
local Logger = require("kulala.logger")
local Oauth = require("kulala.cmd.oauth")
local Table = require("kulala.utils.table")

local M = {}

local function auth_template()
  return {
    ["Type"] = "OAuth2",
    ["Username"] = "",
    ["Scope"] = "",
    ["Client ID"] = "",
    ["Client Secret"] = "",
    ["Grant Type"] = {
      "Authorization Code",
      "Client Credentials",
      "Device Authorization",
      "Implicit",
      "Password",
    },
    ["Use ID Token"] = false,
    ["Redirect URL"] = "",
    ["Token URL"] = "",
    ["Custom Request Parameters"] = {
      ["my-custom-parameter"] = "my-custom-value",
      ["access_type"] = {
        ["Value"] = "offline",
        ["Use"] = "In Auth Request",
      },
      ["audience"] = {
        ["Use"] = "In Token Request",
        ["Value"] = "https://my-audience.com/",
      },
      ["usage"] = {
        ["Use"] = "In Auth Request",
        ["Value"] = "https://my-usage.com/",
      },
      ["resource"] = {
        "https =//my-resource/resourceId1",
        "https =//my-resource/resourceId2",
      },
    },
    ["Password"] = "",
    ["PKCE"] = {
      true,
      {
        ["Code Challenge Method"] = {
          "Plain",
          "SHA-256",
        },
        ["Code Verifier"] = "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM",
      },
    },
    ["Revoke URL"] = "",
    ["Device Auth URL"] = "",
    ["Acquire Automatically"] = true,
    ["Auth URL"] = "",
    ["JWT"] = {
      header = {
        alg = "RS256",
        typ = "JWT",
      },
      payload = {
        ia = 0,
        exp = 50,
      },
    },
  }
end

local function get_env()
  local cur_env = vim.g.kulala_selected_env or Config.get().default_env
  local env = DB.find_unique("http_client_env") or (Env.get_env() and DB.find_unique("http_client_env")) or {}

  local auth = vim.tbl_get(env, cur_env, "Security", "Auth") or Table.set_at(env, { cur_env, "Security", "Auth" }, {})

  return auth
end

local function update_auth_config(name, value)
  local file_name = "http-client.env.json"
  local public_env_path = Fs.find_file_in_parent_dirs(file_name)

  if not public_env_path then
    public_env_path = Fs.get_current_buffer_dir() .. "/" .. file_name
    Fs.write_json(public_env_path, {})
    Logger.info("Created public env file: " .. public_env_path)
  end

  local cur_env = vim.g.kulala_selected_env or Config.get().default_env
  local public_env = Fs.read_json(public_env_path) or {}

  Table.set_at(public_env, { cur_env, "Security", "Auth", name }, value)

  Fs.write_json(public_env_path, public_env, true)
  Env.get_env()
end

local function add_new_config()
  local name = vim.fn.input("Enter new config name: ")
  if name and name ~= "" then
    update_auth_config(name, auth_template())
    Logger.info("Added new Auth config: " .. name)
  end
end

local function remove_config(value)
  local confirm = vim.fn.confirm("Are you sure you want to remove " .. value .. "?", "&Yes\n&No")
  if confirm == 1 then
    update_auth_config(value, nil)
    Logger.info("Removed Auth config: " .. value)
  end
end

local function edit_env_file(config, picker, name)
  local file = name or "http-client.env.json"
  file = Fs.find_file_in_parent_dirs(file)
  if not file then return end

  picker:close()
  vim.cmd(('edit +/"%s": %s'):format(config, file))

  return true
end

local function edit_private_env_file(config, picker)
  return edit_env_file(config, picker, "http-client.private.env.json")
end

local commands = {
  a = { add_new_config, "Add new Auth configuration" },
  e = { edit_env_file, "Edit Auth configuration" },
  p = { edit_private_env_file, "Edit private Auth configuration" },
  m = { remove_config, "Remove Auth configuration" },
  g = { Oauth.acquire_token, "Get new token" },
  f = { Oauth.refresh_token, "Refresh token" },
  r = { Oauth.revoke_token, "Revoke token" },
}

local keys_hint = " (a:Add e:Edit p:Edit private m:Remove g:Get new f:Refresh r:Revoke)"

local function open_auth_telescope()
  local actions = require("telescope.actions")

  local env = get_env()
  local config_names = vim.tbl_keys(env)

  local action_state = require("telescope.actions.state")
  local finders = require("telescope.finders")
  local pickers = require("telescope.pickers")
  local previewers = require("telescope.previewers")
  local config = require("telescope.config").values

  pickers
    .new({}, {
      results_title = "Auth Configurations",
      prompt_title = keys_hint,
      finder = finders.new_table({
        results = config_names,
      }),

      attach_mappings = function(prompt_bufnr, map)
        local function run_cmd(cmd)
          local selection = action_state.get_selected_entry()
          if not selection then return end

          local picker = {
            close = function()
              actions.close(prompt_bufnr)
            end,
          }

          if commands[cmd][1](selection.value, picker) == true then return end

          actions.close(prompt_bufnr)
          M.open_auth_config()
        end

        actions.select_default:replace(function()
          run_cmd("e")
        end)

        vim.iter(commands):each(function(key)
          map("n", key, function()
            run_cmd(key)
          end, { desc = commands[key][2] })
        end)

        return true
      end,

      previewer = previewers.new_buffer_previewer({
        title = "Configuration Details",
        define_preview = function(self, entry)
          local config_data = env[entry.value]
          if not config_data then return end

          local lines = vim.split(vim.inspect(config_data), "\n")

          vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
          vim.api.nvim_set_option_value("filetype", "lua", { buf = self.state.bufnr })
        end,
      }),

      sorter = config.generic_sorter({}),
    })
    :find()
end

local function open_auth_snacks()
  local env = get_env()
  local config_names = vim.tbl_keys(env)

  local items = vim.iter(config_names):fold({}, function(acc, name)
    local config_data = env[name]
    table.insert(acc, {
      text = name,
      label = name,
      data = config_data,
      content = vim.inspect(config_data),
    })
    return acc
  end)

  table.sort(items, function(a, b)
    return a.text:lower() > b.text:lower()
  end)

  local run_cmd = function(key, ctx, item)
    if commands[key][1](item.text, ctx) == true then return end
    ctx:close()
    M.open_auth_config()
  end

  local _actions = {}
  local keys = {}

  vim.iter(commands):each(function(key)
    _actions[key] = function(ctx, item, action)
      run_cmd(key, ctx, item)
    end
    keys[key] = { key, mode = { "n" }, desc = commands[key][2] }
  end)

  snacks_picker({
    title = "Auth Configurations",
    items = items,
    actions = _actions,
    layout = vim.tbl_deep_extend("force", snacks_picker.config.layout("telescope"), {
      reverse = true,
      layout = {
        box = "horizontal",
        width = 0.8,
        height = 0.9,
        { box = "vertical" },
        { win = "preview", width = 0.6 },
      },
    }),
    preview = function(ctx)
      local bufnr = ctx.picker.layout.wins.preview.buf

      vim.api.nvim_set_option_value("modifiable", true, { buf = bufnr })
      vim.api.nvim_set_option_value("filetype", "lua", { buf = bufnr })

      vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, vim.split(ctx.item.content or "", "\n"))

      return true
    end,
    win = {
      preview = {
        title = "Configuration Details",
        wo = {
          number = false,
          relativenumber = false,
          signcolumn = "no",
          winbar = (" "):rep(10) .. keys_hint,
          wrap = false,
          sidescrolloff = 1,
        },
      },
      input = { keys = keys },
      list = { title = "Auth Configurations" },
    },
    confirm = function(picker, item)
      run_cmd("e", picker, item)
    end,
  })
end

M.open_auth_config = function()
  if has_snacks then
    open_auth_snacks()
  elseif has_telescope then
    open_auth_telescope()
  else
    Logger.warn("Telescope or Sancks is required for auth token management")
  end
end

M.get_env = get_env

return M
