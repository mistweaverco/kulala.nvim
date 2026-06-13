-- luacheck: ignore 631
-- Ignores lines too long

---@class kulala.ui.win_config: vim.api.keyset.win_config
---@field bo table<string, any> Buffer options
---@field wo table<string, any> Window options

---@class KulalaDefaultConfigKulalaCore
---@field path string|nil Path to kulala-core executable
---@field timeout number|nil Timeout in milliseconds for the kulala-core sub-process; nil disables the timeout
---@field data_dir string|nil Override for kulala-core data dir
---@field download_url string|"https://github.com/mistweaverco/kulala-core/releases/download/%s/%s" Override for download url

---@class KulalaDefaultConfigSession
---@field restore boolean Restore request history and UI after sourcing a vim session

---@class KulalaDefaultConfigResponseFormat
---@field indent number Indentation
---@field expand_tabs boolean False, if you want to use tabs instead of spaces
---@field sort_keys boolean False, if you want to preserve the original key order

---@class KulalaDefaultConfigUiIconsInlay
---@field loading string
---@field done string
---@field error string

---@class KulalaDefaultConfigUiIcons
---@field inlay KulalaDefaultConfigUiIconsInlay
---@field lualine string
---@field textHighlight string Highlight group for request elapsed time
---@field loadingHighlight string
---@field doneHighlight string
---@field errorHighlight string

---@class KulalaDefaultConfigUiReport
---@field show_script_output boolean|"on_error"
---@field show_asserts_output boolean|"on_error"|"failed_only"
---@field show_summary boolean|"on_error"
---@field headersHighlight string
---@field successHighlight string
---@field errorHighlight string

---@class KulalaDefaultConfigUiPickersSnacks
---@field layout fun(): table

---@class KulalaDefaultConfigUiPickers
---@field snacks KulalaDefaultConfigUiPickersSnacks

---@alias KulalaWinbarPane "body"|"headers"|"headers_body"|"script_output"|"stats"|"verbose"|"report"|"help"

---@class KulalaDefaultConfigUi
---@field display_mode "split"|"float"
---@field split_direction "above"|"right"|"below"|"left"|"vertical"|"horizontal"
---@field win_opts kulala.ui.win_config
---@field default_view "body"|"headers"|"headers_body"|"verbose"|"report"|fun(response: Response)
---@field winbar boolean
---@field default_winbar_panes KulalaWinbarPane[]
---@field winbar_labels table<KulalaWinbarPane, string>
---@field winbar_labels_keymaps boolean
---@field show_variable_info_text false|"float"
---@field show_icons "signcolumn"|"on_request"|"above_request"|"below_request"|nil
---@field icons KulalaDefaultConfigUiIcons
---@field syntax_hl table<string, string|vim.api.keyset.highlight>
---@field show_request_summary boolean
---@field max_response_size number
---@field max_request_size number
---@field report KulalaDefaultConfigUiReport
---@field scratchpad_default_contents string[]
---@field disable_news_popup boolean
---@field lua_syntax_hl boolean
---@field pickers KulalaDefaultConfigUiPickers
---@field grinch_mode boolean

---@class KulalaDefaultConfigLsp
---@field enable boolean
---@field filetypes string[]
---@field enforce_external_script_naming_convention boolean
---@field keymaps boolean|table
---@field on_attach fun(client: table, buf: number)|nil

---@class KulalaDefaultConfig
---@field kulala_core KulalaDefaultConfigKulalaCore
---@field session KulalaDefaultConfigSession
---@field default_env string Default environment name
---@field environment_scope "b"|"g" Scope of variables. *g*lobal can leak into other *b*uffers
---@field vscode_rest_client_environmentvars boolean Read vscode rest-client environment variables
---@field response_format KulalaDefaultConfigResponseFormat
---@field ui KulalaDefaultConfigUi
---@field lsp KulalaDefaultConfigLsp
---@field debug number
---@field generate_bug_report boolean
---@field global_keymaps boolean|table
---@field global_keymaps_prefix string
---@field kulala_keymaps boolean|table
---@field kulala_keymaps_prefix string
