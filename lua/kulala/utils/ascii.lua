local M = {}

-- Returns a waterfall diagram from a table of timings
-- @param timings (table): Table of actions with name and duration
-- @param opts (table): Optional parameters
--  - max_width (number): Maximum width of the diagram
M.get_waterfall_timings = function(timings, opts)
  -- Set default options and override with provided opts
  opts = opts or {}
  local max_width = opts.max_width or 120

  -- Calculate the total time
  local total_time = 0
  for _, action in ipairs(timings) do
    total_time = total_time + action.duration
  end

  -- Calculate the total width needed for all bars
  local total_bar_width = 0
  for _, action in ipairs(timings) do
    local proportion = action.duration / total_time
    total_bar_width = total_bar_width + proportion * max_width
  end

  -- Determine if scaling is needed
  local scale_factor = 1
  if total_bar_width > max_width then
    scale_factor = max_width / total_bar_width
  end

  -- Render each action as a line in the waterfall diagram
  local lines = {}
  local current_pos = 0
  for _, action in ipairs(timings) do
    -- Calculate the proportion of the max width for this action, scaled if needed
    local proportion = action.duration / total_time
    local width = math.floor(proportion * max_width * scale_factor)

    -- Create the line with the action name and corresponding bar
    local line = string.format(
      "%-15s | %s%s %sms",
      action.name,
      string.rep(" ", current_pos),
      string.rep("█", width),
      action.duration
    )

    table.insert(lines, line)

    -- Update the current position for the next action
    current_pos = current_pos + width
  end

  return lines
end

return M
