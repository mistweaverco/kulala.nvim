local M = {}

M.default_global_keymaps = {
  ["Open scratchpad"] = {
    "b",
    function()
      require("kulala").scratchpad()
    end,
  },
  ["Open kulala"] = {
    "o",
    function()
      require("kulala").open()
    end,
  },
  ["Close window"] = {
    "q",
    function()
      require("kulala").close()
    end,
    ft = { "http", "rest" },
  },
  ["Copy as cURL"] = {
    "c",
    function()
      require("kulala").copy()
    end,
    ft = { "http", "rest" },
  },
  ["Paste from curl"] = {
    "C",
    function()
      require("kulala").from_curl()
    end,
    ft = { "http", "rest" },
  },
  ["Inspect current request"] = {
    "i",
    function()
      require("kulala").inspect()
    end,
    ft = { "http", "rest" },
  },
  ["Select environment"] = {
    "e",
    function()
      require("kulala").set_selected_env()
    end,
    ft = { "http", "rest" },
  },
  ["Manage Auth Config"] = {
    "u",
    function()
      require("kulala.ui.auth_manager").open_auth_config()
    end,
    ft = { "http", "rest" },
  },
  ["Send request"] = {
    "s",
    function()
      require("kulala").run()
    end,
    mode = { "n", "v" },
  },
  ["Send request <cr>"] = {
    "<CR>",
    function()
      require("kulala").run()
    end,
    mode = { "n", "v" },
    ft = { "http", "rest" },
  },
  ["Send all requests"] = {
    "a",
    function()
      require("kulala").run_all()
    end,
    mode = { "n", "v" },
  },
  ["Replay the last request"] = {
    "r",
    function()
      require("kulala").replay()
    end,
  },
  ["Download GraphQL schema"] = {
    "g",
    function()
      require("kulala").download_graphql_schema()
    end,
    ft = { "http", "rest" },
  },
  ["Jump to next request"] = {
    "n",
    function()
      require("kulala").jump_next()
    end,
    ft = { "http", "rest" },
  },
  ["Jump to previous request"] = {
    "p",
    function()
      require("kulala").jump_prev()
    end,
    ft = { "http", "rest" },
  },
  ["Find request"] = {
    "f",
    function()
      require("kulala").search()
    end,
    ft = { "http", "rest" },
  },
  ["Toggle headers/body"] = {
    "t",
    function()
      require("kulala").toggle_view()
    end,
    ft = { "http", "rest" },
  },
  ["Show stats"] = {
    "S",
    function()
      require("kulala").show_stats()
    end,
    ft = { "http", "rest" },
  },
  ["Clear globals"] = {
    "x",
    function()
      require("kulala").scripts_clear_global()
    end,
    ft = { "http", "rest" },
  },
  ["Clear cached files"] = {
    "X",
    function()
      require("kulala").clear_cached_files()
    end,
    ft = { "http", "rest" },
  },
}

-- Keymaps for Kulala window only
M.default_kulala_keymaps = {
  ["Show headers"] = {
    "H",
    function()
      require("kulala.ui").show_headers()
    end,
  },
  ["Show body"] = {
    "B",
    function()
      require("kulala.ui").show_body()
    end,
  },
  ["Show headers and body"] = {
    "A",
    function()
      require("kulala.ui").show_headers_body()
    end,
  },
  ["Show verbose"] = {
    "V",
    function()
      require("kulala.ui").show_verbose()
    end,
  },
  ["Show script output"] = {
    "O",
    function()
      require("kulala.ui").show_script_output()
    end,
  },
  ["Show stats"] = {
    "S",
    function()
      require("kulala.ui").show_stats()
    end,
  },
  ["Show report"] = {
    "R",
    function()
      require("kulala.ui").show_report()
    end,
  },
  ["Show filter"] = {
    "F",
    function()
      require("kulala.ui").toggle_filter()
    end,
  },
  ["Next response"] = {
    "]",
    function()
      require("kulala.ui").show_next()
    end,
  },
  ["Previous response"] = {
    "[",
    function()
      require("kulala.ui").show_previous()
    end,
  },
  ["Jump to response"] = {
    "<CR>",
    function()
      require("kulala.ui").keymap_enter()
    end,
    mode = { "n", "v" },
    desc = "also: Update filter and Send WS message for WS connections",
  },
  ["Clear responses history"] = {
    "X",
    function()
      require("kulala.ui").clear_responses_history()
    end,
  },
  ["Send WS message"] = {
    "<S-CR>",
    function()
      require("kulala.cmd.websocket").send()
    end,
    mode = { "n", "v" },
  },
  ["Interrupt requests"] = {
    "<C-c>",
    function()
      require("kulala.ui").interrupt_requests()
    end,
    desc = "also: CLose WS connection",
  },
  ["Show help"] = {
    "?",
    function()
      require("kulala.ui").show_help()
    end,
  },
  ["Show news"] = {
    "g?",
    function()
      require("kulala.ui").show_news()
    end,
  },
  ["Close"] = {
    "q",
    function()
      require("kulala.ui").close_kulala_buffer()
    end,
  },
}

local function collect_global_keymaps()
  local config = require("kulala.config")
  local config_global_keymaps = config.options.global_keymaps
  local prefix = config.options.global_keymaps_prefix
  local global_keymaps, ft_keymaps = {}, {}

  if not config_global_keymaps then return end

  local default_keymaps = {}
  vim.iter(vim.deepcopy(M.default_global_keymaps)):each(function(name, map)
    map[1] = prefix .. map[1]
    default_keymaps[name] = map
  end)

  config_global_keymaps = type(config_global_keymaps) == "table"
      and vim.tbl_extend("force", default_keymaps, config_global_keymaps)
    or default_keymaps

  vim.iter(config_global_keymaps):each(function(name, map)
    if not map then return end
    map.desc = map.desc or name

    if map.ft then
      vim.iter({ map.ft }):flatten():each(function(ft)
        ft_keymaps[ft] = vim.list_extend(ft_keymaps[ft] or {}, { map })
      end)
    else
      global_keymaps = vim.list_extend(global_keymaps, { map })
    end
  end)

  return global_keymaps, ft_keymaps
end

local function set_keymap(map, buf)
  vim.keymap.set(map.mode or "n", map[1], map[2], { buffer = buf, desc = map.desc, silent = true, nowait = true })
end

local function create_ft_autocommand(ft, maps)
  vim.api.nvim_create_autocmd({ "BufEnter", "BufRead", "BufNewFile", "BufFilePost", "FileType" }, {
    group = vim.api.nvim_create_augroup("Kulala filetype setup for *." .. ft, { clear = true }),
    pattern = { "*." .. ft, ft },
    desc = "Kulala: setup keymaps for http filetypes",
    callback = function(ev)
      vim.iter(maps):each(function(map)
        set_keymap(map, ev.buf)
      end)
    end,
  })
end

M.get_kulala_keymaps = function()
  local config = require("kulala.config")
  local config_kulala_keymaps = config.options.kulala_keymaps

  if not config_kulala_keymaps then return end

  config_kulala_keymaps = type(config_kulala_keymaps) == "table"
      and vim.tbl_extend("force", M.default_kulala_keymaps, config_kulala_keymaps)
    or M.default_kulala_keymaps

  return config_kulala_keymaps
end

M.setup_kulala_keymaps = function(buf)
  local keymaps = M.get_kulala_keymaps() or {}

  vim.iter(keymaps):each(function(name, map)
    if map then
      map.desc = map.desc or name
      set_keymap(map, buf)
    end
  end)

  return keymaps
end

M.setup_global_keymaps = function()
  local global_keymaps, ft_keymaps = collect_global_keymaps()

  vim.iter(global_keymaps or {}):each(function(map)
    set_keymap(map)
  end)

  vim.iter(ft_keymaps or {}):each(function(ft, maps)
    create_ft_autocommand(ft, maps)
  end)
  return global_keymaps, ft_keymaps
end

return M
