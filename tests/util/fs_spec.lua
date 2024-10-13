local Fs = require("kulala.utils.fs")

local assert = require("luassert")

describe("kulala.utils.fs", function()
  -- restore all changed done by luassert before each test run
  local snapshot

  before_each(function()
    snapshot = assert:snapshot()
  end)

  after_each(function()
    snapshot:revert()
  end)

  describe("join_paths", function()
    if Fs.os == "windows" then
      it("joins mixed on windows", function()
        local expected = "C:\\a\\b\\c"
        local actual = Fs.join_paths("C:\\a", "b", "c")
        assert.are.same(expected, actual)
      end)
      it("joins no-mixed on windows", function()
        local expected = "C:\\a\\b\\c"
        local actual = Fs.join_paths("C:\\a", "b", "c")
        assert.are.same(expected, actual)
      end)
      it("fixes ps on windows", function()
        local expected = "C:\\a\\user\\bin\\blah\\blubb"
        local actual = Fs.join_paths("C:\\a", "user/bin", "blah/blubb")
        assert.are.same(expected, actual)
      end)
    else
      it("joins mixed on unix", function()
        local expected = "/a/b/c"
        local actual = Fs.join_paths("/a", "b", "c")
        assert.are.same(expected, actual)
      end)
      it("joins no-mixed on unix", function()
        local expected = "/a/b/c"
        local actual = Fs.join_paths("/a", "b", "c")
        assert.are.same(expected, actual)
      end)
      it("joins more mixed on unix", function()
        local expected = "/a/user/bin/blah/blubb"
        local actual = Fs.join_paths("/a", "user/bin", "blah/blubb")
        assert.are.same(expected, actual)
      end)
    end
  end)
end)
