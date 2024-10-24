local SHLEX = require("kulala.lib.shlex")

-- testing data from cpython implementation
-- https://github.com/python/cpython/blob/4a6b1f179667e2a8c6131718eb78a15f726e047b/Lib/test/test_shlex.py#L73
local posix_data = [[x|x|
foo bar|foo|bar|
foo bar|foo|bar|
foo bar |foo|bar|
foo   bar    bla     fasel|foo|bar|bla|fasel|
x y  z              xxxx|x|y|z|xxxx|
\x bar|x|bar|
\ x bar| x|bar|
\ bar| bar|
foo \x bar|foo|x|bar|
foo \ x bar|foo| x|bar|
foo \ bar|foo| bar|
foo "bar" bla|foo|bar|bla|
"foo" "bar" "bla"|foo|bar|bla|
"foo" bar "bla"|foo|bar|bla|
"foo" bar bla|foo|bar|bla|
foo 'bar' bla|foo|bar|bla|
'foo' 'bar' 'bla'|foo|bar|bla|
'foo' bar 'bla'|foo|bar|bla|
'foo' bar bla|foo|bar|bla|
blurb foo"bar"bar"fasel" baz|blurb|foobarbarfasel|baz|
blurb foo'bar'bar'fasel' baz|blurb|foobarbarfasel|baz|
""||
''||
\"|"|
"\""|"|
"foo\ bar"|foo\ bar|
"foo\\ bar"|foo\ bar|
"foo\\ bar\""|foo\ bar"|
"foo\\" bar\"|foo\|bar"|
"foo\\ bar\" dfadf"|foo\ bar" dfadf|
"foo\\\ bar\" dfadf"|foo\\ bar" dfadf|
"foo\\\x bar\" dfadf"|foo\\x bar" dfadf|
"foo\x bar\" dfadf"|foo\x bar" dfadf|
\'|'|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
"foo\\\x bar\" df'a\ 'df"|foo\\x bar" df'a\ 'df|
\"foo|"foo|
\"foo\x|"foox|
"foo\x"|foo\x|
"foo\ "|foo\ |
foo\ xx|foo xx|
foo\ x\x|foo xx|
foo\ x\x\"|foo xx"|
"foo\ x\x"|foo\ x\x|
"foo\ x\x\\"|foo\ x\x\|
"foo\ x\x\\""foobar"|foo\ x\x\foobar|
"foo\ x\x\\"\'"foobar"|foo\ x\x\'foobar|
"foo\ x\x\\"\'"fo'obar"|foo\ x\x\'fo'obar|
"foo\ x\x\\"\'"fo'obar" 'don'\''t'|foo\ x\x\'fo'obar|don't|
"foo\ x\x\\"\'"fo'obar" 'don'\''t' \\|foo\ x\x\'fo'obar|don't|\|
'foo\ bar'|foo\ bar|
'foo\\ bar'|foo\\ bar|
foo\ bar|foo bar|
foo#bar\nbaz|foo|baz|
:-) ;-)|:-)|;-)|
áéíóú|áéíóú|
]]

-- broken data are test cases which works well in CPython shlex, but do not in Lua version
local broken_data = [[
foo "" bar|foo||bar|
foo '' bar|foo||bar|
foo "" "" "" bar|foo||||bar|
foo '' '' '' bar|foo||||bar|
]]

local function splitlines(str, sep)
  if sep == nil then
    sep = "\r?\n"
  end
  local pos = 0
  return function()
    if pos >= #str then
      return nil
    end
    local s, e = str:find(sep, pos)
    local line = str:sub(pos, s and s - 1)
    pos = (e or #str) + 1
    return line
  end
end

local function split(str, sep)
  local t = {}
  for part in splitlines(str, sep) do
    table.insert(t, part)
  end
  return t
end

-- reimplementation of test_shlex.py setUp code
-- https://github.com/python/cpython/blob/962304a54ca79da0838cf46dd4fb744045167cdd/Lib/test/test_shlex.py#L141
local function test_cases(str)
  local it = splitlines(str)
  return function()
    local line = it()
    if line == nil then
      return nil
    end
    local expected = split(line, "|")
    local input = expected[1]
    input = input:gsub("\\n", "\n")
    table.remove(expected, 1)
    return input, expected
  end
end

describe("posix", function()
  for input, expected in test_cases(posix_data) do
    it("'" .. input .. "'", function()
      local actual = SHLEX.split(input)
      assert.same(expected, actual)
    end)
  end
end)

describe("curl", function()
  it("should return url as one string", function()
    local input = "curl http://example.com"
    local actual = SHLEX.split(input)
    local expected = { "curl", "http://example.com" }
    assert.same(expected, actual)
  end)
end)

describe("broken", function()
  for input, expected in test_cases(broken_data) do
    it("'" .. input .. "'", function()
      local actual = SHLEX.split(input)
      assert.is_not.same(expected, actual)
    end)
  end
end)
