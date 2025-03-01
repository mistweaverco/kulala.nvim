local CONFIG = require("kulala.config")
local DB = require("kulala.db")
local UI_utils = require("kulala.ui.utils")

---To avoid circular dependencies
local UI = setmetatable({}, {
  __index = function(_, key)
    return require("kulala.ui")[key]
  end,
})

local function set_response_summary(buf)
  local config = CONFIG.get()
  if not config.ui.show_request_summary then return end

  local responses = DB.global_update().responses
  local response = UI.get_current_response()
  local idx = UI.get_current_response_pos()
  local duration = response.duration == "" and 0 or UI_utils.pretty_ms(response.duration)

  local data = vim
    .iter({
      {
        "Request: "
          .. idx
          .. "/"
          .. #responses
          .. "  Code: "
          .. response.status
          .. "  Duration: "
          .. duration
          .. "  Time: "
          .. vim.fn.strftime("%b %d %X", response.time),
      },
      { "URL: " .. response.method .. " " .. response.url .. "  Status: " .. response.response_code },
      { "Buffer: " .. response.buf_name .. "::" .. response.line },
      { "" },
    })
    :flatten()
    :totable()

  vim.api.nvim_buf_set_lines(buf, 0, 0, false, data)
  UI_utils.highlight_range(UI.get_kulala_buffer(), 0, 0, 3, config.ui.summaryTextHighlight)
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
  local out = vim.deepcopy(response.assert_output.testResults) or {}
  local sep = (" "):rep(4)

  local status = true

  out = vim
    .iter(out)
    :map(function(assert)
      status = status and assert[2] == 0
      return { sep .. assert[1], assert[2] }
    end)
    :totable()

  _ = #out > 0 and table.insert(out, 1, { "" })

  return out, status and 0 or 1
end

local function get_report_summary(stats)
  local config = CONFIG.get().ui.report
  local summary = {}

  local tbl = UI_utils.Ptable:new({
    header = { "Summary", "Total", "Successful", "Failed" },
    widths = { 20, 20, 20, 20 },
  })

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

local function update_report_stats(stats, request_status, asserts)
  stats = stats
    or {
      total = 0,
      success = 0,
      failed = 0,
      assert_total = 0,
      assert_success = 0,
      assert_failed = 0,
    }

  local function update_stat(t, value, status)
    status = status or 0
    t[value] = t[value] + (status == 0 and 1 or 0)
  end

  update_stat(stats, "total")
  update_stat(stats, "success", request_status)
  update_stat(stats, "failed", request_status)

  vim.iter(asserts):each(function(assert)
    local status = assert[2]
    if status then
      update_stat(stats, "assert_total")
      update_stat(stats, "assert_success", status)
      update_stat(stats, "assert_failed", status)
    end
  end)

  return stats
end

local function generate_requests_report()
  local db = DB.global_update()
  if #db.responses == 0 then return {} end

  local config = CONFIG.get().ui.report
  local show_script = config.show_script_output
  local show_asserts = config.show_asserts_output

  local row, report = "", {}
  local response_status, stats

  local tbl = UI_utils.Ptable:new({
    header = { "Line", "URL", "Status", "Time", "Duration" },
    widths = { 5, 50, 8, 10, 10 },
  })

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

    local asserts, assert_status = get_assert_output(response)
    response_status = response.status + assert_status
    stats = update_report_stats(stats, response_status, asserts)

    table.insert(report, { row, response_status == 0 and config.successHighlight or config.errorHighlight })

    _ = show_script
      and not (response_status == 0 and show_script == "on_error")
      and vim.list_extend(report, get_script_output(response))

    if show_asserts and not (assert_status == 0 and show_asserts == "on_error") then
      vim.iter(asserts):each(function(assert)
        _ = not (show_asserts == "failed_only" and assert[2] == 0)
          and table.insert(report, { assert[1], assert[2] == 0 and config.successHighlight or config.errorHighlight })
      end)
    end

    table.insert(report, { "" })
  end)

  _ = config.show_summary and vim.list_extend(report, get_report_summary(stats))

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
  set_response_summary = set_response_summary,
  generate_requests_report = generate_requests_report,
  print_http_spec = print_http_spec,
}
