local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local Markdown = require("kulala.ui.markdown")
local UI_utils = require("kulala.ui.utils")

---To avoid circular dependencies
local UI = setmetatable({}, {
  __index = function(_, key)
    return require("kulala.ui")[key]
  end,
})

local function with_buffer_write(buf, fn)
  local modifiable = vim.bo[buf].modifiable
  local readonly = vim.bo[buf].readonly
  vim.bo[buf].modifiable = true
  vim.bo[buf].readonly = false
  local ok, err = pcall(fn)
  vim.bo[buf].modifiable = modifiable
  vim.bo[buf].readonly = readonly
  if not ok then error(err) end
end

local function hide_response_summary()
  local buf = UI.get_kulala_buffer()
  if not buf then return end

  local config = CONFIG.get().ui
  if not config.show_request_summary then return end

  with_buffer_write(buf, function()
    vim.fn.deletebufline(buf, 1, 4)
    UI_utils.clear_highlights(buf)
  end)
end

local function set_response_summary(buf)
  local config = CONFIG.get().ui
  if not config.show_request_summary then return end

  local responses = DB.global_update().responses
  local response = UI.get_current_response()
  local assert_status = response.assert_status and "success" or (response.assert_status == false and "failed" or "-")
  local idx = UI.get_current_response_pos()
  local duration = UI_utils.pretty_ms(response.duration)
  local cur_env = require("kulala.parser.env").get_current_env()

  local data = vim
    .iter({
      {
        "Request: "
          .. idx
          .. "/"
          .. #responses
          .. "  Code: "
          .. response.code
          .. "  Duration: "
          .. duration
          .. "  Time: "
          .. vim.fn.strftime("%b %d %X", response.time),
      },
      {
        "URL: "
          .. response.method
          .. " "
          .. response.url:gsub("\n", "")
          .. "  Env: "
          .. cur_env
          .. "  Status: "
          .. response.response_code
          .. "  Assert: "
          .. assert_status,
      },
      { "Buffer: " .. response.buf_name .. "::" .. response.line .. "  Name: " .. response.name },
      { "" },
    })
    :flatten()
    :totable()

  with_buffer_write(buf, function()
    vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
    UI_utils.highlight_range(
      buf,
      0,
      0,
      2,
      response.status and config.report.successHighlight or config.report.errorHighlight
    )
  end)
end

---@param response Response
---@param show_asserts string|boolean
---@return string|nil, table stats
local function format_assert_output(response, show_asserts)
  local results = response.assert_output and response.assert_output.results or {}
  if #results == 0 then return nil end

  local parts = { "#### Asserts\n" }
  local stats = { total = 0, success = 0, failed = 0 }
  local test_suite = nil

  vim.iter(results):each(function(assert)
    local value = assert.status and "success" or "failed"
    stats[value] = stats[value] + 1
    stats.total = stats.total + 1

    if assert.status and show_asserts == "failed_only" then return end

    if #assert.name > 0 and test_suite ~= assert.name then
      test_suite = assert.name
      table.insert(parts, ("**%s**\n"):format(Markdown.md_escape_cell(test_suite)))
    elseif #assert.name == 0 then
      test_suite = nil
    end

    local status = assert.status and "PASS" or "FAIL"
    local message = assert.message or ""
    table.insert(parts, ("- **%s** %s\n"):format(status, Markdown.md_escape_cell(message)))
  end)

  if #parts == 1 then return nil, stats end
  return table.concat(parts, "\n"), stats
end

---@param stats table
---@return string
local function format_report_summary(stats)
  local rows = {
    { "", "Total", "Successful", "Failed" },
    {
      "Requests",
      Markdown.md_table_cell(tostring(stats.total or 0)),
      Markdown.md_table_cell(tostring(stats.success or 0)),
      Markdown.md_table_cell(tostring(stats.failed or 0)),
    },
    {
      "Asserts",
      Markdown.md_table_cell(tostring(stats.assert_total or 0)),
      Markdown.md_table_cell(tostring(stats.assert_success or 0)),
      Markdown.md_table_cell(tostring(stats.assert_failed or 0)),
    },
  }
  return "## Summary\n\n" .. Markdown.md_table(rows, "r") .. "\n"
end

local function update_report_stats(stats, response_status, asserts)
  stats = stats
    or {
      total = 0,
      success = 0,
      failed = 0,
      assert_total = 0,
      assert_success = 0,
      assert_failed = 0,
    }

  local value = response_status and "success" or "failed"
  stats[value] = stats[value] + 1
  stats.total = stats.total + 1

  stats.assert_total = stats.assert_total + asserts.total
  stats.assert_success = stats.assert_success + asserts.success
  stats.assert_failed = stats.assert_failed + asserts.failed

  return stats
end

local function generate_requests_report()
  local db = DB.global_update()
  if #db.responses == 0 then return "" end

  local config = CONFIG.get().ui.report
  local show_script = config.show_script_output
  local show_asserts = config.show_asserts_output

  local parts = { "# Requests report\n" }
  local stats

  vim.iter(db.responses):skip(db.previous_response_pos):each(function(response)
    table.insert(
      parts,
      ("## Line %s — HTTP %s\n"):format(
        Markdown.md_escape_cell(tostring(response.line)),
        Markdown.md_escape_cell(tostring(response.response_code or "?"))
      )
    )

    local row = {
      { "Field", "Value" },
      { "URL", Markdown.md_table_cell(response.url) },
      { "Status", Markdown.md_table_cell(tostring(response.response_code or "?")) },
      { "Time", Markdown.md_table_cell(vim.fn.strftime("%H:%M:%S", response.time)) },
      { "Duration", Markdown.md_table_cell(UI_utils.pretty_ms(response.duration)) },
    }
    table.insert(parts, Markdown.md_table(row) .. "\n")

    local asserts, assert_stats = format_assert_output(response, show_asserts)
    stats = update_report_stats(stats, response.status, assert_stats or { total = 0, success = 0, failed = 0 })

    if show_script and not (response.status and show_script == "on_error") then
      local script = Markdown.format_script_output(response)
      if script ~= "_No script output_\n" then
        table.insert(parts, "#### Script output\n")
        table.insert(parts, script)
        table.insert(parts, "")
      end
    end

    if show_asserts and asserts and not (response.assert_status and show_asserts == "on_error") then
      table.insert(parts, asserts)
      table.insert(parts, "")
    end
  end)

  if config.show_summary then table.insert(parts, format_report_summary(stats or {})) end

  return Markdown.trim(table.concat(parts, "\n"))
end

---Prints the parsed Request table into current buffer - uses nvim_put
local function print_http_spec(spec, curl)
  local lines = {}

  table.insert(lines, "# " .. curl)

  local url = spec.method .. " " .. spec.url
  url = spec.http_version ~= "" and url .. " " .. spec.http_version or url

  table.insert(lines, url)

  local headers = vim.tbl_keys(spec.headers)
  table.sort(headers)

  vim.iter(headers):each(function(header)
    table.insert(lines, header .. ": " .. spec.headers[header])
  end)

  if #spec.cookie > 0 then table.insert(lines, "Cookie: " .. spec.cookie) end

  if #spec.body > 0 then
    table.insert(lines, "")

    vim.iter(spec.body):each(function(line)
      line = spec.body[#spec.body] and line or line .. "&"
      table.insert(lines, line)
    end)
  end

  vim.api.nvim_put(lines, "l", false, false)
end

return {
  hide_response_summary = hide_response_summary,
  set_response_summary = set_response_summary,
  generate_requests_report = generate_requests_report,
  print_http_spec = print_http_spec,
}
