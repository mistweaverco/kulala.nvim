local CURL = require("kulala.parser.curl")

describe("curl parse", function()
  it("bad command", function()
    local args = [[urlc 'http://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal(nil, parsed)
  end)

  it("default GET", function()
    local args = [[curl 'http://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.equal(nil, parsed.data)
    assert.same({}, parsed.headers)
    assert.equal("", parsed.http_version)
  end)

  it("-X PATCH", function()
    local args = [[curl -X PATCH 'http://example.com/patch']]
    local parsed = CURL.parse(args)
    assert.equal("PATCH", parsed.method)
    assert.equal("http://example.com/patch", parsed.url)
  end)

  it("--request HEAD", function()
    local args = [[curl --request HEAD 'http://example.com/head']]
    local parsed = CURL.parse(args)
    assert.equal("HEAD", parsed.method)
    assert.equal("http://example.com/head", parsed.url)
  end)

  it("-A agent", function()
    local args = [[curl -A agent 'http://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["user-agent"] = "agent" }, parsed.headers)
  end)

  it("--user-agent user/agent", function()
    local args = [[curl --user-agent user/agent 'http://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["user-agent"] = "user/agent" }, parsed.headers)
  end)

  it("-H 'short: header'", function()
    local args = [[curl -H 'short:header' 'http://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["short"] = "header" }, parsed.headers)
  end)

  it("-H 'short: header' --header 'long:header'", function()
    local args = [[curl -H 'short:header' --header 'long:header' 'http://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["short"] = "header", ["long"] = "header" }, parsed.headers)
  end)

  it("-d data", function()
    local args = [[curl -d data 'https://example.com/post']]
    local parsed = CURL.parse(args)
    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body)
  end)

  it("-d data -X PUT", function()
    local args = [[curl -d data -X PUT 'https://example.com/put']]
    local parsed = CURL.parse(args)
    assert.equal("PUT", parsed.method)
    assert.equal("https://example.com/put", parsed.url)
    assert.equal("data", parsed.body)
    assert.equal("application/x-www-form-urlencoded", parsed.headers["content-type"])
  end)

  it("--data data", function()
    local args = [[curl --data data 'https://example.com/post']]
    local parsed = CURL.parse(args)
    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body)
    assert.equal("application/x-www-form-urlencoded", parsed.headers["content-type"])
  end)

  it("--data-raw data", function()
    local args = [[curl --data-raw data 'https://example.com/post']]
    local parsed = CURL.parse(args)
    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body)
    assert.equal("application/x-www-form-urlencoded", parsed.headers["content-type"])
  end)

  it("-d data -H 'content-type: text/plain'", function()
    local args = [[curl -H 'content-type: text/plain' -d data 'https://example.com/post']]
    local parsed = CURL.parse(args)

    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body)
    assert.equal("text/plain", parsed.headers["content-type"])
  end)

  it("--json", function()
    local args = [[curl --json '{"j": "son"}' 'https://example.com/post']]
    local parsed = CURL.parse(args)

    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal('{"j": "son"}', parsed.body)
    assert.equal("application/json", parsed.headers["content-type"])
    assert.equal("application/json", parsed.headers["accept"])
  end)

  it("--http1.1", function()
    local args = [[curl --http1.1 'https://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("HTTP/1.1", parsed.http_version)
  end)

  it("--http2", function()
    local args = [[curl --http2 'https://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("HTTP/2", parsed.http_version)
  end)

  it("--http3", function()
    local args = [[curl --http3 'https://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("HTTP/3", parsed.http_version)
  end)

  it("trim header value", function()
    local args = [[curl -H 'key:    value    ' 'https://example.com/get']]
    local parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("value", parsed.headers["key"])
  end)

  it("header key case", function()
    local args = [[curl -H 'Header-Key:value' 'https://example.com/get']]
    local parsed = CURL.parse(args)

    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("value", parsed.headers["header-key"])
    assert.equal(nil, parsed.headers["Header-Key"])
  end)
end)
