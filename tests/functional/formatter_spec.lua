---@diagnostic disable: undefined-field, redefined-local

local config = require("kulala.config")
local db = require("kulala.db")
local formatter = require("kulala.cmd.formatter")
local logger = require("kulala.logger")

local h = require("test_helper")

local function setup_http_parser(update)
  if update then
    config.setup()
    require("nvim-treesitter.install").commands.TSUpdateSync["run"]("kulala_http")
  end

  vim.wait(3000, function()
    local parsers = vim.F.npcall(require, "nvim-treesitter.parsers")
    return parsers.has_parser("kulala_http") and db.settings.parser_ver ~= "update"
  end)
end

describe("format", function()
  local buf
  local result

  setup(function()
    setup_http_parser()
  end)

  before_each(function()
    h.delete_all_bufs()
    -- stub(Logger, "info", true)
  end)

  after_each(function()
    -- Logger.info:revert()
  end)

  describe("formats buffer", function()
    it("#wip formats request", function()
      buf = h.create_buf(
        ([[
        ###Request  name
        # @meta
        @foobar=   bar
        # @curl-conect-timeout 200
        @user =   pass  
        GET http://httpbin.org/post HTTP/1.1
        content-type  : application/json
        Accept: application/json

        {
          "results": [
            { "id": 1, "desc": "some_username" },
            { "id": 2, "desc": "another_username" }
          ]
        }

        > {%
          client.log("post request executed");
        %}
      ]]):to_table(true),
        "basic.http"
      )

      result = formatter.format(buf)
      vim.notify(result or "")
      -- DevTools.log("result: ", result)
    end)
  end)
end)
