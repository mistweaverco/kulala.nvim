local M = {}

local christmas_messages = {
  "Ho ho ho! Merry Christmas from Kulala!",
  "Santa's API is checking the naughty/nice list...",
  "Let it snow, let it code, let it REST!",
  "Your request is wrapped and ready!",
  "Frosty says: May your responses be merry!",
  "Rudolph is guiding your request through the night!",
  "Jingle bells, jingle bells, JSON all the way!",
  "Deck the halls with API calls!",
  "Wishing you bug-free holidays!",
  "Cookies enabled for Santa's visit!",
}

local christmas_icons = { "🎄", "🎅", "❄️", "🎁", "⛄", "🦌", "🔔", "🎄", "🌟", "🍪" }

M.is_christmas_season = function()
  local m = os.date("*t").month
  return m == 1 or m == 12
end

M.get_random_message = function()
  local idx = math.random(#christmas_messages)
  return christmas_icons[idx] .. " " .. christmas_messages[idx]
end

return M
