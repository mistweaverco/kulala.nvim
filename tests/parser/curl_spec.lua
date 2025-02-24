local CURL = require("kulala.parser.curl")
local args, parsed

describe("curl parse", function()
  it("bad command", function()
    args = [[urlc 'http://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal(nil, parsed)
  end)

  it("default GET", function()
    args = [[curl 'http://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.equal(nil, parsed.data)
    assert.same({}, parsed.headers)
    assert.equal("", parsed.http_version)
  end)

  it("-X PATCH", function()
    args = [[curl -X PATCH 'http://example.com/patch']]
    parsed = CURL.parse(args)
    assert.equal("PATCH", parsed.method)
    assert.equal("http://example.com/patch", parsed.url)
  end)

  it("--request HEAD", function()
    args = [[curl --request HEAD 'http://example.com/head']]
    parsed = CURL.parse(args)
    assert.equal("HEAD", parsed.method)
    assert.equal("http://example.com/head", parsed.url)
  end)

  it("-A agent", function()
    args = [[curl -A agent 'http://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["user-agent"] = "agent" }, parsed.headers)
  end)

  it("--user-agent user/agent", function()
    args = [[curl --user-agent user/agent 'http://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["user-agent"] = "user/agent" }, parsed.headers)
  end)

  it("-H 'short: header'", function()
    args = [[curl -H 'short:header' 'http://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["short"] = "header" }, parsed.headers)
  end)

  it("-H 'short: header' --header 'long:header'", function()
    args = [[curl -H 'short:header' --header 'long:header' 'http://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("http://example.com/get", parsed.url)
    assert.same({ ["short"] = "header", ["long"] = "header" }, parsed.headers)
  end)

  it("-d data", function()
    args = [[curl -d data 'https://example.com/post']]
    parsed = CURL.parse(args)
    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body[1])
  end)

  it("-d data -X PUT", function()
    args = [[curl -d data -X PUT 'https://example.com/put']]
    parsed = CURL.parse(args)
    assert.equal("PUT", parsed.method)
    assert.equal("https://example.com/put", parsed.url)
    assert.equal("data", parsed.body[1])
    assert.equal("application/x-www-form-urlencoded", parsed.headers["content-type"])
  end)

  it("--data data", function()
    args = [[curl --data data -d '{"key":"value"}' 'https://example.com/post']]
    parsed = CURL.parse(args)
    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body[1])
    assert.equal('{"key":"value"}', parsed.body[2])
    assert.equal("application/x-www-form-urlencoded", parsed.headers["content-type"])
  end)

  it("--data-raw data", function()
    args = [[curl --data-raw data 'https://example.com/post']]
    parsed = CURL.parse(args)
    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body[1])
    assert.equal("application/x-www-form-urlencoded", parsed.headers["content-type"])
  end)

  it("-d data -H 'content-type: text/plain'", function()
    args = [[curl -H 'content-type: text/plain' -d data 'https://example.com/post']]
    parsed = CURL.parse(args)

    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal("data", parsed.body[1])
    assert.equal("text/plain", parsed.headers["content-type"])
  end)

  it("--json", function()
    args = [[curl --json '{"j": "son"}' 'https://example.com/post']]
    parsed = CURL.parse(args)

    assert.equal("POST", parsed.method)
    assert.equal("https://example.com/post", parsed.url)
    assert.equal('{"j": "son"}', parsed.body[1])
    assert.equal("application/json", parsed.headers["content-type"])
    assert.equal("application/json", parsed.headers["accept"])
  end)

  it("--http1.1", function()
    args = [[curl --http1.1 'https://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("HTTP/1.1", parsed.http_version)
  end)

  it("--http2", function()
    args = [[curl --http2 'https://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("HTTP/2", parsed.http_version)
  end)

  it("--http3", function()
    args = [[curl --http3 'https://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("HTTP/3", parsed.http_version)
  end)

  it("trim header value", function()
    args = [[curl -H 'key:    value    ' 'https://example.com/get']]
    parsed = CURL.parse(args)
    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("value", parsed.headers["key"])
  end)

  it("header key case", function()
    args = [[curl -H 'Header-Key:value' 'https://example.com/get']]
    parsed = CURL.parse(args)

    assert.equal("GET", parsed.method)
    assert.equal("https://example.com/get", parsed.url)
    assert.equal("value", parsed.headers["header-key"])
    assert.equal(nil, parsed.headers["Header-Key"])
  end)

  it("parses all flags - short", function()
    args = [[
    curl -X POST 'http://localhost:3001/api/protected-resource' 
    -H 'Accept: */*' 
    -H 'Accept-Language: en-GB,en;q=0.9' 
    -b 'connect.sid=s%3AInsWZZ8JKnTDILqV1B5V; sessionId=dac4c39ed8320ed66eff280ffaed5b0b' 
    -H 'sec-ch-ua-platform: "macOS"'
    -A 'Mozilla/5.0'
    -d '{"key": "value"}'
    -d '{"key2": "value2"}'
    --http2
    --json '{ "key3": "value3" }'
    ]]
    parsed = CURL.parse(args)

    assert.has_properties(parsed, {
      method = "POST",
      url = "http://localhost:3001/api/protected-resource",
      http_version = "HTTP/2",
      headers = {
        accept = "application/json",
        ["accept-language"] = "en-GB,en;q=0.9",
        ["content-type"] = "application/json",
        ["sec-ch-ua-platform"] = '"macOS"',
        ["user-agent"] = "Mozilla/5.0",
      },
      cookie = "connect.sid=s%3AInsWZZ8JKnTDILqV1B5V; sessionId=dac4c39ed8320ed66eff280ffaed5b0b",
      body = {
        '{"key": "value"}',
        '{"key2": "value2"}',
        '{ "key3": "value3" }',
      },
    })
  end)

  it("parses all flags - long", function()
    args = [[
    curl --request POST 'http://localhost:3001/api/protected-resource' 
    --header 'Accept: */*' 
    --header 'Accept-Language: en-GB,en;q=0.9' 
    --cookie 'connect.sid=s%3AInsWZZ8JKnTDILqV1B5V; sessionId=dac4c39ed8320ed66eff280ffaed5b0b' 
    --header 'sec-ch-ua-platform: "macOS"'
    --user-agent 'Mozilla/5.0'
    --data '{"key": "value"}'
    -d '{"key2": "value2"}'
    --http2
    --json '{ "key3": "value3" }'
    ]]
    parsed = CURL.parse(args)

    assert.has_properties(parsed, {
      method = "POST",
      url = "http://localhost:3001/api/protected-resource",
      http_version = "HTTP/2",
      headers = {
        accept = "application/json",
        ["accept-language"] = "en-GB,en;q=0.9",
        ["content-type"] = "application/json",
        ["sec-ch-ua-platform"] = '"macOS"',
        ["user-agent"] = "Mozilla/5.0",
      },
      cookie = "connect.sid=s%3AInsWZZ8JKnTDILqV1B5V; sessionId=dac4c39ed8320ed66eff280ffaed5b0b",
      body = {
        '{"key": "value"}',
        '{"key2": "value2"}',
        '{ "key3": "value3" }',
      },
    })
  end)
end)
