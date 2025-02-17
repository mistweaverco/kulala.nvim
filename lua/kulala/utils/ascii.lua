local M = {}

-- Returns a waterfall diagram from a table of timings
-- @param timings (table): Table of actions with name and duration
-- @param opts (table): Optional parameters
--  - max_width (number): Maximum width of the diagram
M.get_waterfall_timings = function(timings, opts)
  -- Set default options and override with provided opts
  opts = opts or {}
  local max_width = opts.max_width or 80

  -- Calculate the available width for the bars
  local label_width = 15 -- Fixed label width
  local separator_width = 4 -- " | " and two spaces
  local duration_width = 5 -- Max length for the duration in ms (e.g., "0.84s")
  local available_bar_width = max_width - label_width - separator_width - duration_width

  -- Calculate the total time
  local total_time = 0
  for _, action in ipairs(timings) do
    total_time = total_time + action.duration
  end

  -- Calculate the total width needed for all bars
  local total_bar_width = 0
  for _, action in ipairs(timings) do
    local proportion = action.duration / total_time
    total_bar_width = total_bar_width + proportion * available_bar_width
  end

  -- Determine if scaling is needed
  local scale_factor = 1
  if total_bar_width > available_bar_width then scale_factor = available_bar_width / total_bar_width end

  -- Render each action as a line in the waterfall diagram
  local lines = {}
  local current_pos = 0
  for _, action in ipairs(timings) do
    if action.name ~= "redirect" and action.duration ~= 0 then
      -- Calculate the proportion of the max width for this action, scaled if needed
      local proportion = action.duration / total_time
      local width = math.floor(proportion * available_bar_width * scale_factor)

      -- Convert the duration to milliseconds
      local duration_str = string.format("%.0fms", action.duration * 1000)
      -- Create the line with the action name and corresponding bar
      local line = string.format(
        "%-15s | %s%s %s",
        action.name,
        string.rep(" ", current_pos),
        string.rep("█", width),
        duration_str
      )

      table.insert(lines, line)
      -- Update the current position for the next action
      current_pos = current_pos + width
    end
  end

  -- Add the total time to the end
  table.insert(lines, string.rep("-", max_width))
  table.insert(lines, string.format("%-15s | Total Time: %.0fms", "", total_time * 1000))

  return lines
end

return M
