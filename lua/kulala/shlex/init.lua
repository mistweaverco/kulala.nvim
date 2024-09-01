-- https://raw.githubusercontent.com/BodneyC/shlex-lua/main/shlex.lua
local M = {}

local function some(o)
  return o and #o > 0
end

local function none(o)
  return not some(o)
end

M.shlex = {
  whitespace = ' \t\r\n',
  whitespace_split = false,
  quotes = [['"]],
  escape = [[\]],
  escapedquotes = '"',
  state = ' ',
  pushback = {},
  lineno = 1,
  debug = 0,
  token = '',
  commenters = '#',
  wordchars = 'abcdfeghijklmnopqrstuvwxyz' ..
    'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_',
}
M.shlex.__index = M.shlex

local sr = require('kulala.shlex.stringreader')

function M.shlex:create(str, posix, punctuation_chars)
  local o = {}
  setmetatable(o, M.shlex)

  o.sr = sr(str or '')

  if not posix then
    o.eof = ''
  end

  o.posix = posix == true
  if o.posix then
    o.wordchars = o.wordchars ..
                    'ßàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿ' ..
                    'ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ'
  end

  if punctuation_chars then
    punctuation_chars = '();<>|&'
  else
    punctuation_chars = ''
  end

  o.punctuation_chars = punctuation_chars

  if punctuation_chars then
    o._pushback_chars = {}
    o.wordchars = o.wordchars .. '~-./*?='
    for i = 1, #o.punctuation_chars do
      local c = o.punctuation_chars:sub(i, i)
      o.wordchars:gsub(c, '', 1, true)
    end
  end

  return o
end

function M.shlex:push_token(tok)
  table.insert(self.pushback, tok)
end

function M.shlex:read_token()
  local quoted = false
  local escapedstate = ' '
  local nextchar

  while true do

    if some(self.punctuation_chars) and some(self._pushback_chars) then
      nextchar = table.remove(self._pushback_chars)
    else
      nextchar = self.sr:read(1)
    end

    if nextchar == '\n' then
      self.lineno = self.lineno + 1
    end

    if self.debug >= 3 then
      print('shlex: in state \'' .. (self.state or 'nil') ..
              '\' I see character: \'' .. (nextchar or 'nil') .. '\'')
    end

    if none(self.state) then
      self.token = ''
      break

    elseif self.state == ' ' then
      if none(nextchar) then
        self.state = nil
        break

      elseif self.whitespace:find(nextchar, 1, true) then
        if self.debug >= 2 then
          print('shlex: I see whitespace in whitespace state')
        end
        if some(self.token) or (self.posix and quoted) then
          break
        else
          goto continue
        end

      elseif self.commenters:find(nextchar, 1, true) then
        self.sr:readline()
        self.lineno = self.lineno + 1

      elseif self.posix and self.escape:find(nextchar, 1, true) then
        escapedstate = 'a'
        self.state = nextchar

      elseif self.wordchars:find(nextchar, 1, true) then
        self.token = nextchar
        self.state = 'a'

      elseif self.punctuation_chars:find(nextchar, 1, true) then
        self.token = nextchar
        self.state = 'c'

      elseif self.quotes:find(nextchar, 1, true) then
        if not self.posix then
          self.token = nextchar
        end
        self.state = nextchar

      elseif self.whitespace_split then
        self.token = nextchar
        self.state = 'a'

      else
        self.token = nextchar
        if some(self.token) or (self.posix and quoted) then
          break
        else
          goto continue
        end
      end

    elseif self.quotes:find(self.state, 1, true) then
      quoted = true
      if none(nextchar) then
        if self.debug >= 2 then
          print('shlex: I see EOF in quotes state')
        end
        error('no closing quotation')
      end
      if nextchar == self.state then
        if not self.posix then
          self.token = self.token .. nextchar
          self.state = ' '
          break
        else
          self.state = 'a'
        end
      elseif self.posix and self.escape:find(nextchar, 1, true) and
        self.escapedquotes:find(self.state, 1, true) then
        escapedstate = self.state
        self.state = nextchar
      else
        self.token = self.token .. nextchar
      end

    elseif self.escape:find(self.state, 1, true) then
      if none(nextchar) then
        if self.debug >= 2 then
          print('shlex: I see EOF in escape state')
        end
        error('no escaped character')
      end
      if self.quotes:find(escapedstate, 1, true) and nextchar ~= self.state and
        nextchar ~= escapedstate then
        self.token = self.token .. self.state
      end
      self.token = self.token .. nextchar
      self.state = escapedstate

    elseif self.state == 'a' or self.state == 'c' then
      if none(nextchar) then
        self.state = nil
        break

      elseif self.whitespace:find(nextchar, 1, true) then
        if self.debug >= 2 then
          print('shlex: I see whitespace in word state')
        end
        self.state = ' '
        if some(self.token) or (self.posix and quoted) then
          break
        else
          goto continue
        end

      elseif self.commenters:find(nextchar, 1, true) then
        self.sr:readline()
        self.lineno = self.lineno + 1
        if self.posix then
          self.state = ' '
          if some(self.token) or (self.posix and quoted) then
            break
          else
            goto continue
          end
        end

      elseif self.state == 'c' then
        if self.punctuation_chars:find(nextchar, 1, true) then
          self.token = self.token .. nextchar
        else
          if not self.whitespace:find(nextchar, 1, true) then
            table.insert(self._pushback_chars, nextchar)
          end
          self.state = ' '
          break
        end

      elseif self.posix and self.quotes:find(nextchar, 1, true) then
        self.state = nextchar

      elseif self.posix and self.escape:find(nextchar, 1, true) then
        escapedstate = 'a'
        self.state = nextchar

      elseif self.wordchars:find(nextchar, 1, true) or
        self.quotes:find(nextchar, 1, true) or
        (self.whitespace_split and
          not self.punctuation_chars:find(nextchar, 1, true)) then
        self.token = self.token .. nextchar

      else
        if some(self.punctuation_chars) then
          table.insert(self._pushback_chars, nextchar)
        else
          table.insert(self.pushback, nextchar)
        end
        self.state = ' '
        if some(self.token) or (self.posix and quoted) then
          break
        else
          goto continue
        end

      end

    end

    ::continue::
  end

  local result = self.token
  self.token = ''
  if self.posix and not quoted and result == '' then
    result = nil
  end
  if result and result:find('^%s*$') then
    result = self:read_token()
  end
  if self.debug > 1 then
    if result then
      print('shlex: raw token=' .. result)
    else
      print('shlex: raw token=EOF')
    end
  end
  return result
end

function M.shlex:next()
  if some(self.pushback) then
    return table.remove(self.pushback)
  end
  local raw = self:read_token()
  return raw
end

function M.shlex:list()
  local parts = {}
  while true do
    local next = self:next()
    if next == self.eof or next == nil then
      break
    end
    table.insert(parts, next)
  end
  return parts
end

setmetatable(M.shlex, {
  __call = M.shlex.create,
})

function M.split(str, comments, posix)
  if not str then
    str = ''
  end
  if type(posix) == 'nil' then
    posix = true
  end
  local lex = M.shlex(str)
  lex.posix = posix
  if comments == false then
    lex.commenters = ''
  end
  return lex:list()
end

function M.join(parts)
  local ret = ''
  for idx, part in ipairs(parts) do
    ret = ret .. M.quote(part)
    if idx ~= #parts then
      ret = ret .. ' '
    end
  end
  return ret
end

M._unsafe = '^@%+=:,./-'

function M.quote(s)
  if none(s) then
    return [['']]
  end
  local found = false
  if s:find('%w') then
    found = true
  else
    for i = 1, #s do
      local c = s:sub(i, i)
      if M._unsafe:find(c, 1, true) then
        found = true
        break
      end
    end
  end
  if not found then
    return s
  end
  return '\'' .. s:gsub('\'', '\'"\'"\'') .. '\''
end

return M
