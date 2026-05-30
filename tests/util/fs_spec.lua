describe("kulala.utils.fs", function()
  describe("join_paths on windows", function()
    it("joins mixed on windows", function()
      local Fs = require("kulala.utils.fs")
      Fs.os = "windows"
      Fs.ps = "\\"
      local expected = "C:\\a\\b\\c"
      local actual = Fs.join_paths("C:\\a", "b", "c")
      assert.are.same(expected, actual)
    end)
    it("joins no-mixed on windows", function()
      local Fs = require("kulala.utils.fs")
      Fs.os = "windows"
      Fs.ps = "\\"
      local expected = "C:\\a\\b\\c"
      local actual = Fs.join_paths("C:\\a", "b", "c")
      assert.are.same(expected, actual)
    end)
    it("fixes ps on windows", function()
      local Fs = require("kulala.utils.fs")
      Fs.os = "windows"
      Fs.ps = "\\"
      local expected = "C:\\a\\user\\bin\\blah\\blubb"
      local actual = Fs.join_paths("C:\\a", "user/bin", "blah/blubb")
      assert.are.same(expected, actual)
    end)
  end)
  describe("join_paths on linux", function()
    it("joins mixed on unix", function()
      local Fs = require("kulala.utils.fs")
      Fs.os = "unix"
      Fs.ps = "/"
      local expected = "/a/b/c"
      local actual = Fs.join_paths("/a", "b", "c")
      assert.are.same(expected, actual)
    end)
    it("joins no-mixed on unix", function()
      local Fs = require("kulala.utils.fs")
      Fs.os = "unix"
      Fs.ps = "/"
      local expected = "/a/b/c"
      local actual = Fs.join_paths("/a", "b", "c")
      assert.are.same(expected, actual)
    end)
    it("joins more mixed on unix", function()
      local Fs = require("kulala.utils.fs")
      Fs.os = "unix"
      Fs.ps = "/"
      local expected = "/a/user/bin/blah/blubb"
      local actual = Fs.join_paths("/a", "user/bin", "blah/blubb")
      assert.are.same(expected, actual)
    end)
  end)
end)
