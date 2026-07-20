local EnvManager = require("kulala.ui.env_manager")
local Fs = require("kulala.utils.fs")
local KULALA_CORE = require("kulala.cmd.kulala_core_bridge")

local test_api = EnvManager._test

describe("env_manager cache", function()
  local tmp_root
  local saved_core

  before_each(function()
    tmp_root = vim.fn.getcwd() .. "/tests/.tmp/env_manager_cache_" .. tostring(vim.loop.hrtime())
    vim.fn.mkdir(tmp_root, "p")
    vim.fn.mkdir(tmp_root .. "/level1", "p")
    vim.fn.mkdir(tmp_root .. "/level2", "p")

    saved_core = {
      enabled = KULALA_CORE.enabled,
      list_environments_async = KULALA_CORE.list_environments_async,
    }

    EnvManager.invalidate_cache()
  end)

  after_each(function()
    KULALA_CORE.enabled = saved_core.enabled
    KULALA_CORE.list_environments_async = saved_core.list_environments_async
    EnvManager.invalidate_cache()
    vim.fn.delete(tmp_root, "rf")
  end)

  local function write_json(path, data)
    Fs.write_json(path, data)
  end

  local function setup_inheritance_fixture()
    write_json(tmp_root .. "/http-client.env.json", {
      dev = { HOST = "parent", folder_level = 0 },
    })
    write_json(tmp_root .. "/level1/http-client.env.json", {
      dev = { HOST = "level1", folder_level = 1 },
    })
    write_json(tmp_root .. "/level2/http-client.env.json", {
      dev = { HOST = "level2", folder_level = 2 },
    })
  end

  it("reads merged disk env from the provided start_dir", function()
    setup_inheritance_fixture()

    local level1_env = test_api.read_http_client_env_from_disk(tmp_root .. "/level1")
    local level2_env = test_api.read_http_client_env_from_disk(tmp_root .. "/level2")

    assert.are.equal("level1", level1_env.dev.HOST)
    assert.are.equal(1, level1_env.dev.folder_level)
    assert.are.equal("level2", level2_env.dev.HOST)
    assert.are.equal(2, level2_env.dev.folder_level)
  end)

  it("keeps separate cache entries per document directory", function()
    setup_inheritance_fixture()

    local cwd_a = tmp_root .. "/level1"
    local cwd_b = tmp_root .. "/level2"
    local key_a = test_api.env_catalog_cache_key(cwd_a)
    local key_b = test_api.env_catalog_cache_key(cwd_b)

    assert.is_not.same(key_a, key_b)

    KULALA_CORE.enabled = function()
      return true
    end

    local finish_a
    KULALA_CORE.list_environments_async = function(cwd, on_done)
      if cwd == cwd_a then
        finish_a = function()
          on_done({ environments = { dev = { HOST = "level1-async" } } }, nil)
        end
        return
      end
      if cwd == cwd_b then on_done({ environments = { dev = { HOST = "level2-async" } } }, nil) end
    end

    local done_b = false
    test_api.refresh_environment_catalog_async(false, cwd_b, function(env)
      assert.are.equal("level2-async", env.dev.HOST)
      done_b = true
    end)
    assert(vim.wait(2000, function()
      return done_b
    end))

    local done_a = false
    test_api.refresh_environment_catalog_async(false, cwd_a, function(env)
      assert.are.equal("level1-async", env.dev.HOST)
      done_a = true
    end)

    assert(finish_a, "expected async load for level1")
    finish_a()
    assert(vim.wait(2000, function()
      return done_a
    end))

    local entry_b = test_api.catalog_cache.entries[key_b]
    assert.is_not_nil(entry_b)
    assert.are.equal("level2-async", entry_b.http_client_env.dev.HOST)
  end)

  it("invalidates all cached entries", function()
    setup_inheritance_fixture()

    KULALA_CORE.enabled = function()
      return false
    end

    local cwd = tmp_root .. "/level1"
    local cache_key = test_api.env_catalog_cache_key(cwd)
    local done = false

    test_api.refresh_environment_catalog_async(false, cwd, function(env)
      assert.are.equal("level1", env.dev.HOST)
      done = true
    end)
    assert(vim.wait(2000, function()
      return done
    end))
    assert.is_not_nil(test_api.catalog_cache.entries[cache_key])

    EnvManager.invalidate_cache()
    assert.is_nil(test_api.catalog_cache.entries[cache_key])

    local reloaded = false
    test_api.refresh_environment_catalog_async(false, cwd, function(env)
      assert.are.equal("level1", env.dev.HOST)
      reloaded = true
    end)
    assert(vim.wait(2000, function()
      return reloaded
    end))
    assert.is_not_nil(test_api.catalog_cache.entries[cache_key])
  end)

  it("returns cached catalog without reloading when cache key matches", function()
    setup_inheritance_fixture()

    KULALA_CORE.enabled = function()
      return true
    end

    local calls = 0
    KULALA_CORE.list_environments_async = function(_, on_done)
      calls = calls + 1
      on_done({ environments = { dev = { HOST = "cached" } } }, nil)
    end

    local cwd = tmp_root .. "/level2"
    local done_first = false
    test_api.refresh_environment_catalog_async(false, cwd, function()
      done_first = true
    end)
    assert(vim.wait(2000, function()
      return done_first
    end))
    assert.are.equal(1, calls)

    local done_second = false
    test_api.refresh_environment_catalog_async(false, cwd, function(env)
      assert.are.equal("cached", env.dev.HOST)
      done_second = true
    end)
    assert(vim.wait(2000, function()
      return done_second
    end))
    assert.are.equal(1, calls)
  end)
end)
