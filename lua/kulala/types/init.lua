-- luacheck: ignore 631
-- Ignores lines too long

---@class KulalaDefaultConfigKulalaCore
---@field path string|nil Path to kulala-core executable
---@field timeout number Timeout in milliseconds for the kulala-core sub-process
---@field data_dir string|nil Override for kulala-core data dir
---@field download_url string|"https://github.com/mistweaverco/kulala-core/releases/download/%s/%s" Override for download url

---@class KulalaDefaultConfigResponseFormat
---@field indent number Indentation
---@field expand_tabs boolean False, if you want to use tabs instead of spaces
---@field sort_keys boolean False, if you want to preserve the original key order

---@class KulalaDefaultConfig
---@field kulala_core KulalaDefaultConfigKulalaCore
---@field default_env string|"default" Default environment name
---@field environment_scope "b"|"g" Scope of variables. *g*lobal can leak into other *b*uffers
---@field vscode_rest_client_environmentvars boolean Read vscode rest-client environment variables
---@type response_format KulalaDefaultConfigResponseFormat
---@field contenttypes table<string, {ft: string, path
