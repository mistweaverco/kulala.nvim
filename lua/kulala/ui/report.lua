local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local UI_utils = require("kulala.ui.utils")

---To avoid circular dependencies
local UI = setmetatable({}, {
  __index = function(_, key)
    return require("kulala.ui")[key]
  end,
})

local function hide_response_summary()
  local buf = UI.get_kulala_buffer()

  local config = CONFIG.get().ui
  if not config.show_request_summary then return end

  vim.fn.deletebufline(buf, 1, 4)
  UI_utils.clear_highlights(buf)
end

local function set_response_summary(buf)
  local config = CONFIG.get().ui
  if not config.show_request_summary then return end

  local responses = DB.global_update().responses
  local response = UI.get_current_response()
  local assert_status = response.assert_status and "success" or (response.assert_status == false and "failed" or "-")
  local idx = UI.get_current_response_pos()
  local duration = UI_utils.pretty_ms(response.duration)
  local cur_env = vim.g.kulala_selected_env or CONFIG.get().default_env

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

  vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
  UI_utils.highlight_range(
    buf,
    0,
    0,
    2,
    response.status and config.report.successHighlight or config.report.errorHighlight
  )
end

local function get_script_output(response)
  local pre, post = response.script_pre_output, response.script_post_output
  local sep = (" "):rep(4)
  local out = {}

  _ = #pre > 0 and vim.list_extend(out, { "--> Pre-script:" }) and vim.list_extend(out, vim.split(pre, "\n"))
  _ = #post > 0 and vim.list_extend(out, { "<-- Post-script:" }) and vim.list_extend(out, vim.split(post, "\n"))
  _ = #out > 0 and table.insert(out, 1, " ")

  return vim
    .iter(out)
    :map(function(line)
      return #line > 0 and { sep .. line } or nil
    end)
    :totable()
end

local function get_assert_output(response)
  local config = CONFIG.get().ui.report
  local show_asserts = config.show_asserts_output
  local sep = (" "):rep(2)

  local hl, test_suite = "", nil
  local out, value, message = {}, nil, ""
  local stats = { total = 0, success = 0, failed = 0 }

  vim.iter(response.assert_output.results or {}):each(function(assert)
    value = assert.status and "success" or "failed"
    stats[value] = stats[value] + 1
    stats.total = stats.total + 1

    if not (assert.status and show_asserts == "failed_only") then
      hl = assert.status and config.successHighlight or config.errorHighlight

      if #assert.name > 0 and test_suite ~= assert.name then
        test_suite = assert.name
        table.insert(out, { sep .. test_suite .. ":", config.headersHighlight })
      elseif #assert.name == 0 then
        test_suite = nil
      end

      message = test_suite and sep .. assert.message or assert.message
      vim.iter(vim.split(message, "\n")):each(function(line)
        table.insert(out, { sep .. line, hl })
      end)
    end
  end)

  return out, stats
end

local function get_report_summary(stats)
  local config = CONFIG.get().ui.report
  local summary = {}

  local tbl = UI_utils.Ptable:new {
    header = { "Summary", "Total", "Successful", "Failed" },
    widths = { 20, 20, 20, 20 },
  }

  table.insert(summary, { tbl:get_headers(), config.headersHighlight })
  table.insert(summary, {
    tbl:get_row({ "Requests", stats.total, stats.success, stats.failed }, 1),
    { config.successHighlight, 40, 60, config.errorHighlight, 60, 80 },
  })
  table.insert(summary, {
    tbl:get_row({ "Asserts", stats.assert_total, stats.assert_success, stats.assert_failed }, 1),
    { config.successHighlight, 40, 60, config.errorHighlight, 60, 80 },
  })

  return summary
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
  if #db.responses == 0 then return {} end

  local config = CONFIG.get().ui.report
  local show_script = config.show_script_output
  local show_asserts = config.show_asserts_output

  local row, report = "", {}
  local stats

  local tbl = UI_utils.Ptable:new {
    header = { "Line", "URL", "Status", "Time", "Duration" },
    widths = { 5, 50, 8, 10, 15 },
  }

  table.insert(report, { tbl:get_headers(), config.headersHighlight })
  table.insert(report, { "" })

  vim.iter(db.responses):skip(db.previous_response_pos):each(function(response)
    row = tbl:get_row({
      response.line,
      response.url,
      response.response_code,
      vim.fn.strftime("%H:%M:%S", response.time),
      UI_utils.pretty_ms(response.duration),
    }, 1)

    local asserts, assert_stats = get_assert_output(response)
    stats = update_report_stats(stats, response.status, assert_stats)

    table.insert(report, { row, response.status and config.successHighlight or config.errorHighlight })

    _ = show_script
      and not (response.status and show_script == "on_error")
      and vim.list_extend(report, get_script_output(response))

    _ = show_asserts
      and #asserts > 0
      and not (response.assert_status and show_asserts == "on_error")
      and vim.list_extend(report, { { "" } })
      and vim.list_extend(report, asserts)

    table.insert(report, { "" })
  end)

  _ = config.show_summary and vim.list_extend(report, get_report_summary(stats or {}))

  local contents, highlights = {}, {}
  for i, line in ipairs(report) do
    contents[i], highlights[i] = unpack(line)
  end

  return contents, highlights
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

  _ = #spec.cookie > 0 and table.insert(lines, "Cookie: " .. spec.cookie)

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
