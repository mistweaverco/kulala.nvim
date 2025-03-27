local db = require("kulala.db")
local fs = require("kulala.utils.fs")
local h = require("test_helper")
local kulala = require("kulala")
local kulala_config = require("kulala.config")
local oauth = require("kulala.cmd.oauth")

local http_client_path = h.expand_path("requests/http-client.env.json")

local function get_auth_header()
  return db.data.current_request.headers.Authorization:gsub("Bearer ", "")
end

local function get_env()
  return fs.read_json(http_client_path).dev.Security.Auth.GAPI
end

local parse_params = function(str)
  return vim.iter(vim.split(str or "", "&")):fold({}, function(acc, param)
    local key, value = unpack(vim.split(param, "="))
    acc[key] = acc[key] and acc[key] .. " " .. value or value
    return acc
  end)
end

local update_env = function(tbl)
  local env = fs.read_json(http_client_path) or {}
  env.dev.Security.Auth.GAPI = vim.tbl_extend("force", env.dev.Security.Auth.GAPI, tbl)
  fs.write_json(http_client_path, env)
end

describe("#wip oauth", function()
  local curl, system, wait_for_requests
  local http_buf, ui_buf, ui_buf_tick
  local on_request, redirect_request
  local result, expected = {}, {}

  local function get_request(no)
    return system.log[no or 1]
  end

  before_each(function()
    ui_buf_tick = 0
    curl = h.Curl.stub({ ["https://www.secure.com"] = {} })

    stub(vim.uv, "sleep", function() end)

    stub(oauth, "tcp_server", function(host, port, callback)
      result.tcp_server = { host = host, port = port }
      on_request = callback
      return { stop = function() end }
    end)

    stub(vim.ui, "open", function(url)
      result.url_params = parse_params(url:match("%?(.+)")) or {}
      result.url_params.url = url

      vim.schedule(function()
        vim.wait(3000, function()
          return on_request
        end)
        _ = on_request and on_request(redirect_request)
      end)

      return true
    end)

    system = h.System.stub({ "curl" }, {
      on_call = function(system)
        local params = parse_params(system.args.cmd[#system.args.cmd - 1])
        params.url = system.args.cmd[#system.args.cmd]

        system.add_log(params)
        curl.request(system)
      end,
    })

    wait_for_requests = function(requests_no)
      system:wait(3000, function()
        ui_buf = h.get_kulala_buf()
        local tick = ui_buf > 0 and vim.api.nvim_buf_get_changedtick(ui_buf) or 0

        if curl.requests_no >= requests_no and ui_buf > 0 and tick > ui_buf_tick then
          ui_buf_tick = tick
          return true
        end
      end)
    end

    kulala_config.setup({ default_view = "body", debug = 1, jq_path = "no_jq" })
    http_buf = h.create_buf(
      ([[
        GET https://secure.com
        Authorization: Bearer {{$auth.token("GAPI")}}
      ]]):to_table(true),
      h.expand_path("requests/oauth.http")
    )
  end)

  after_each(function()
    h.delete_all_bufs()

    curl.reset()
    system.reset()

    vim.ui.open:revert()
    vim.uv.sleep:revert()
    oauth.tcp_server:revert()

    fs.write_json(http_client_path, fs.read_json(h.expand_path("requests/http-client.env.default.json")))
  end)

  it("returns stored access token if it is not expired", function()
    update_env({ access_token = "stored_access_token", acquired_at = os.time(), expires_in = os.time() + 3600 })

    kulala.run()
    wait_for_requests(1)

    assert.is.same("stored_access_token", get_auth_header())
  end)

  it("returns stored id token if it is not expired", function()
    h.set_buf_lines(
      http_buf,
      ([[
        GET https://secure.com
        Authorization: Bearer {{$auth.idToken("GAPI")}}
      ]]):to_table(true)
    )
    update_env({ id_token = "stored_id_token", acquired_at = os.time(), expires_in = os.time() + 3600 })

    kulala.run()
    wait_for_requests(1)

    assert.is.same("stored_id_token", get_auth_header())
  end)

  it("refreshes access token if it is expired", function()
    curl.stub({
      ["https://token.url"] = { stdout = '{ "access_token": "refreshed_access_token"}' },
    })

    update_env({
      access_token = "expired_access_token",
      acquired_at = os.time() - 10,
      expires_in = 1,
      refresh_token = "refresh_token",
      refresh_token_acquired_at = os.time(),
      refresh_token_expires_in = os.time() + 3600,
    })

    kulala.run()
    wait_for_requests(1)

    assert.has_properties(get_request(), {
      audience = "kulala_api",
      client_id = "client_id",
      client_secret = "client_secret",
      grant_type = "refresh_token",
      refresh_token = "refresh_token",
    })
    assert.is.same("refreshed_access_token", get_auth_header())
  end)

  describe("acquires new access token if it is expired", function()
    before_each(function()
      curl.stub({
        ["https://token.url"] = {
          stdout = '{ "access_token": "new_access_token", "refresh_token":"new_refresh_token"}',
        },
      })
      update_env({ access_token = "expired_access_token" })
    end)

    it("grant type - Password", function()
      update_env({ ["Grant Type"] = "Password" })

      kulala.run()
      wait_for_requests(1)

      assert.has_properties(get_request(), {
        audience = "kulala_api",
        client_id = "client_id",
        client_secret = "client_secret",
        grant_type = "password",
        password = "client_password",
        scope = "scope:sample",
        username = "test@mail.com",
      })

      assert.has_properties(get_env(), {
        access_token = "new_access_token",
        refresh_token = "new_refresh_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)
      assert.near(os.time(), get_env().refresh_token_acquired_at, 1)
    end)

    it("#wip grant type - Client Credentials: generate JWT", function()
      update_env({
        ["Grant Type"] = "Client Credentials",
        private_key = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC5cHDxLOlZKpgT\nLNEF18AlQkxOHwYuP3VOuAeCxwCMlICSmfVRCzl5Zv+36fVTnvSF5tp1J46JI6jD\nM3WIE9UmjcRA13TVfzkoRuEKOfd20/PVEoxAXt4h5xgT4yuuJB1+C+R4xcZY4ul7\neCar1YJ12JJEt8vnZRGEhpjE8FtGvCBdDQ2+d7Qhr2LL8PIYW6mS6++5uCBAno+4\nevOmE2GkeQAfosrkDLSjOtNzF9pEYA5BzW1ZuZJJyWukUvaze4MqFH/6XfqzFPtr\n5XfQo8Olifljteic6JQx9KcvhXI7v1owtCpjkqcXMtiXtR23mRws0h//outYR0o4\nfJuOmouVAgMBAAECggEALJ/lXfRb1yxL2llvl4Na5tx0dlw65Yg5146rqAnxlOLr\nqdvI0A7ubsudgAmaEtxupYZvTcAOKexd4VOR1gRHx/ZXou72W6Y4//tGjmpypbLN\nu5myDI+HzwrInYiOa2KfgkSkX3fgimVYoHDChZlkwq0yTb0ZIX8N3yFww/u/S17y\n4sP3/+94dR6KWZTuufsmknAvByVGtVe3bGszYo77DC3m7+Kx2mR88anuP9a2H3Jf\nldzVCPvJ4bboncTFItxERRiHX/N7xwmNO7MzL5WZRL+GPe9+P/Hr/PKokeQc+yEg\n0cfWqKG0tyTLArRGOOHZ3wHLGuqjSFc+RZiXoL3dxQKBgQDwGSMjdhKa+Ck6SwkU\n26vvTLN5XTwleG9w5Mhj3esKs0DROEGfksFmSCCkFNboDl11RJuUldNwa4AVyZoc\nPbA96jRJGK7AEcNOV9FwdEs8rc0Berfn6klQuE66gsVonIM9fRiq8pYnnZ552Urh\nuHxgQoQL5iWCdl/IZ4kai8FHJwKBgQDFuI/Dv7HjFS9bOkIP7pg/KKYzl6VsUSlp\nEkd67V9TLHwIToq+k2cjmPMRCKD6KYkhbyOMN3GJpk348h9xdY9reIOBAb7hotbs\nQCRYFmuiksKeDoaP8N7MSIjs2C1AMO80RbyB2jLF8R9VIE64xZmUs0RBki5vqvtZ\naqQbpqxs4wKBgQCMbmd7Ckh/k76pddHt/T5nTPl8dugDEpo78dSzdM1RCN9UgA8C\nAphT9sQAtJ+uQxiuyl4lXiy5iGb2V2BoPDylOiMyzdkIRltxqzO5DowjBZTu1JRU\ndVhEekiyFmLYeRLaGB0hf5oLuclDg7CkrX8x3jXVr9son4wOb2BlwnBd6QKBgALs\nZKvHRNEPuiCGLv3fUD720eZHYrnERXF5RLdLlTI8oSTaTHDe6xJ6q3VgBElOnelx\npDvpgfNAEz0QD2j1DQbQxFj+9pyNdNIPbLoksri3pMsDeffc3t50YBnoZFrjnlXO\nhigBWujUVNtEXAWdXlT1hZfWmnsqMwcybXS/NSNzAoGBAJekqSCvUQHdiNWq1BPp\nM998rdujTGmfYCdKLT+c0i1/s3YuGu/h87tTSjXi7Jmq/iNVM2+RoTaGvvD1b+ZC\nGLcVcsqa6qD77WRQZ3q+2sF8v2vSd9oHT0R2jA4U/zVyF9dFOV4tT09xrFh7vLXM\nfYsrQTaSEta7ynoUI5/9NJTJ\n-----END PRIVATE KEY-----\n",
        JWT = {
          header = {
            alg = "HS256",
            typ = "JWT",
          },
          payload = {
            aud = "https://token.url",
            exp = 50,
            iss = "kulala-service-account",
            scope = "devstorage.read_only",
          },
        },
      })

      kulala.run()
      wait_for_requests(2)

      assert.is_true(#get_request().assertion > 0)
      assert.has_properties(get_request(), {
        audience = "kulala_api",
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
        url = "https://token.url",
      })

      assert.has_properties(get_env(), {
        access_token = "new_access_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)

      assert.is.same("new_access_token", get_auth_header())
    end)

    it("grant type - Client Credentials: use provided", function()
      update_env({
        ["Grant Type"] = "Client Credentials",
        assertion = "custom_assertion",
      })

      kulala.run()
      wait_for_requests(2)

      assert.is_true(#get_request().assertion > 0)
      assert.has_properties(get_request(), {
        audience = "kulala_api",
        grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
        url = "https://token.url",
      })

      assert.has_properties(get_env(), {
        access_token = "new_access_token",
        acquired_at = os.time(),
      })
      assert.near(os.time(), get_env().acquired_at, 1)

      assert.is.same("new_access_token", get_auth_header())
    end)

    --TODO: use provided assetion, add exp and iat, payload.exp

    it("grant type - Implicit", function()
      update_env({ ["Grant Type"] = "Implicit" })
      redirect_request = "access_token=new_access_token"

      kulala.run()
      wait_for_requests(1)

      -- Opens browser with the Auth URL
      assert.has.match("https://auth.url", result.url_params.url)
      assert.has_properties(result.url_params, {
        access_type = "offline",
        audience = "kulala_api",
        client_id = "client_id",
        redirect_uri = "http://localhost:8080",
        response_type = "token",
        scope = "scope:sample",
      })

      -- Saves new access token and refresh token
      assert.is.same("new_access_token", get_auth_header())
      assert.has_properties(get_env(), {
        access_token = "new_access_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)
    end)

    it("grant type - Authorization code", function()
      update_env({ ["Grant Type"] = "Authorization Code" })
      redirect_request = "code=auth_code&state=state"

      kulala.run()
      wait_for_requests(2)

      -- Opens browser with the Auth URL
      assert.has.match("https://auth.url", result.url_params.url)
      assert.has_properties(result.url_params, {
        access_type = "offline",
        audience = "kulala_api",
        client_id = "client_id",
        redirect_uri = "http://localhost:8080",
        response_type = "code",
        scope = "scope:sample",
      })

      --- Starts tcp server to intercept the redirect request
      assert.has_properties(result.tcp_server, {
        host = "127.0.0.1",
        port = "8080",
      })

      --- Intercepts request to redirect url
      assert.is.same("auth_code", get_env().code)
      assert.is.same("state", get_env().state)

      -- Sends request to Token URL:
      assert.has_properties(get_request(), {
        audience = "kulala_api",
        client_id = "client_id",
        client_secret = "client_secret",
        code = "auth_code",
        grant_type = "authorization_code",
        redirect_uri = "http://localhost:8080",
      })

      -- Saves new access token and refresh token
      assert.is.same("new_access_token", get_auth_header())
      assert.has_properties(get_env(), {
        code = "auth_code",
        access_token = "new_access_token",
        refresh_token = "new_refresh_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)
      assert.near(os.time(), get_env().refresh_token_acquired_at, 1)
    end)

    it("grant type - Device code", function()
      curl.stub({
        ["https://device.url"] = {
          stdout = [[
            { 
              "device_code": "new_device_code", 
              "user_code": "new_user_code", 
              "verification_url": "verification_url", 
              "interval": 1,
              "expires_in": 3600
            }
          ]],
        },
      })
      update_env({ ["Grant Type"] = "Device Authorization", ["Device Auth URL"] = "https://device.url" })
      on_request = function() end

      kulala.run()
      wait_for_requests(3)

      -- Sends request to Device URL
      assert.has_properties(get_request(), {
        url = "https://device.url",
        access_type = "offline",
        audience = "kulala_api",
        client_id = "client_id",
        scope = "scope:sample",
      })

      -- Saves new device code and user code
      assert.has_properties(get_env(), {
        user_code = "new_user_code",
        device_code = "new_device_code",
        verification_url = "verification_url",
        interval = 1,
      })
      assert.near(os.time(), get_env().acquired_at, 1)

      -- Opens browser with the verification URL and copies the user code to clipboard
      assert.is.same("verification_url", result.url_params.url)
      assert.is.same("new_user_code", vim.fn.getreg("+"))

      -- Sends request to Token URL
      assert.has_properties(get_request(2), {
        url = "https://token.url",
        audience = "kulala_api",
        client_id = "client_id",
        client_secret = "client_secret",
        device_code = "new_device_code",
        grant_type = "urn:ietf:params:oauth:grant-type:device_code",
      })

      -- Saves new access token and refresh token
      assert.has_properties(get_env(), {
        access_token = "new_access_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)

      assert.is.same("new_access_token", get_auth_header())
    end)

    it("adds custom response_type to Auth request", function()
      update_env({ ["Grant Type"] = "Authorization Code", response_type = "code token" })
      redirect_request = "code=auth_code&state=state"

      kulala.run()
      wait_for_requests(2)

      assert.has_properties(result.url_params, {
        response_type = "code token",
      })
    end)

    describe("adds PKCE params to Auth request", function()
      it("adds PKCE params to Auth request from config", function()
        update_env({
          ["Grant Type"] = "Authorization Code",
          PKCE = {
            ["Code Verifier"] = "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM",
            ["Code Challenge Method"] = "S256",
          },
        })
        redirect_request = "code=auth_code"

        kulala.run()
        wait_for_requests(2)

        assert.is_true(#result.url_params.code_challenge > 0)
        assert.is.same("S256", result.url_params.code_challenge_method)

        assert.has_properties(get_request(), {
          code_verifier = "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM",
        })
      end)

      it("adds PKCE params to Auth request calculated", function()
        update_env({
          ["Grant Type"] = "Authorization Code",
          PKCE = true,
        })
        redirect_request = "code=auth_code&state=state"

        kulala.run()
        wait_for_requests(2)

        assert.is_true(#result.url_params.code_challenge > 0)
        assert.is.same("S256", result.url_params.code_challenge_method)

        assert.is_true(#get_request().code_verifier > 0)
      end)
    end)

    it("adds custom params to requests", function()
      update_env({
        ["Grant Type"] = "Authorization Code",
        ["Custom Request Parameters"] = {
          audience = {
            Use = "In Token Request",
            Value = "https://my-audience.com/",
          },
          ["my-custom-parameter"] = "my-custom-value",
          resource = { "https://my-resource/resourceId1", "https://my-resource/resourceId2" },
          usage = {
            Use = "In Auth Request",
            Value = "https://my-usage.com/",
          },
          state = {
            Use = "Everywhere",
            Value = "state",
          },
        },
      })
      redirect_request = "code=auth_code&state=state"

      kulala.run()
      wait_for_requests(2)

      assert.has_properties(result.url_params, {
        ["my-custom-parameter"] = "my-custom-value",
        resource = "https://my-resource/resourceId1 https://my-resource/resourceId2",
        usage = "https://my-usage.com/",
        state = "state",
      })

      assert.has_properties(get_request(), {
        ["my-custom-parameter"] = "my-custom-value",
        resource = "https://my-resource/resourceId1 https://my-resource/resourceId2",
        audience = "https://my-audience.com/",
        state = "state",
      })
    end)

    --TODO:
    -- pkce check plain and other methods
    -- jwt other digests
    -- custom response_type
  end)
end)
