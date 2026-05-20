local Verbose = require("kulala.ui.verbose")

describe("verbose markdown", function()
  it("formats kulala-core response with header tables", function()
    local out = Verbose.format {
      method = "GET",
      url = "https://example.com/api",
      response_code = 200,
      _kulala_core = true,
      request = {
        url = "https://example.com/api",
        headers_tbl = { Host = "example.com", Accept = "application/json" },
        body = '{"x":1}',
      },
      headers = "Content-Type: application/json\n\n",
      headers_tbl = { ["content-type"] = "application/json" },
      body = '{"ok":true}',
      stats = {
        response_code = 200,
        timings = {
          { name = "namelookup", duration = 0.001 },
          { name = "total", duration = 0.05 },
        },
      },
    }

    assert.matches("# `GET`", out)
    assert.matches("| Header", out)
    assert.matches("| `Host`", out)
    assert.matches("`application/json`", out)
    assert.matches("## Response", out)
    assert.matches("```json", out)
    assert.matches("## Transfer timings", out)
  end)

  it("formats redirect hops with separate sections", function()
    local out = Verbose.format {
      method = "GET",
      url = "https://example.com/final",
      response_code = 200,
      _kulala_core = true,
      _kulala_redirect_chain = {
        {
          status = 302,
          url = "https://example.com/start",
          headers = { location = "https://example.com/final" },
          timings = { dns = 1, total = 10 },
          body = { type = "text", content = "" },
        },
        {
          status = 200,
          url = "https://example.com/final",
          headers = {},
          timings = { total = 20 },
          body = { type = "text", content = "done" },
        },
      },
      headers = "",
      body = "done",
    }

    assert.matches("## Redirect chain", out)
    assert.matches("## Hop 1", out)
    assert.not_matches("## Hop 2", out)
  end)

  it("wraps header values in backticks so */* is not emphasis", function()
    local out = Verbose.format {
      method = "GET",
      url = "https://example.com",
      response_code = 200,
      _kulala_core = true,
      request = { url = "https://example.com", headers_tbl = { Accept = "*/*" } },
      headers = "",
      body = "ok",
    }
    assert.matches("`%*/%*`", out)
  end)

  it("parses curl trace into connection bullets and header tables", function()
    local trace = table.concat({
      "* Trying 127.0.0.1:3001...",
      "* Connected to localhost (127.0.0.1) port 3001",
      "> GET /greeting HTTP/1.1",
      "> Host: localhost:3001",
      "< HTTP/1.1 200 OK",
      "< Server: Jetty",
    }, "\n")

    local out = Verbose.format_legacy {
      method = "GET",
      url = "http://localhost:3001/greeting",
      errors = trace,
      body = "<h1>Hi</h1>",
    }

    assert.matches("### Connection & TLS", out)
    assert.matches("Trying 127%.0%.0%.1", out)
    assert.matches("### Request %(from trace%)", out)
    assert.matches("| `Host`", out)
    assert.matches("## Response body", out)
  end)
end)
