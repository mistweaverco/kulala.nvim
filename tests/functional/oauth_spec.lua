local cmd = require("kulala.cmd")
local db = require("kulala.db")
local fs = require("kulala.utils.fs")
local h = require("test_helper")
local kulala = require("kulala")
local kulala_config = require("kulala.config")
local oauth = require("kulala.cmd.oauth")
local tcp = require("kulala.cmd.tcp")

local http_client_path = h.expand_path("requests/http-client.env.json")
local http_client_private_path = h.expand_path("requests/http-client.private.env.json")

local function restore_http_client_files(format)
  fs.write_json(http_client_path, fs.read_json(h.expand_path("requests/http-client.env.default.json")), format)
  fs.write_json(
    http_client_private_path,
    fs.read_json(h.expand_path("requests/http-client.private.env.default.json")),
    format
  )
end

local function get_auth_header()
  return db.data.current_request.headers.Authorization:gsub("Bearer ", "")
end

local function get_env()
  return fs.read_json(http_client_private_path).dev.Security.Auth.GAPI.auth_data
end

local parse_params = function(str)
  return vim.iter(vim.split(str or "", "&")):fold({}, function(acc, param)
    local key, value = unpack(vim.split(param, "="))
    acc[key] = acc[key] and acc[key] .. " " .. value or value
    return acc
  end)
end

local update_env = function(tbl, private)
  local path = private and http_client_private_path or http_client_path
  local env = fs.read_json(path) or {}

  env.dev.Security.Auth.GAPI = vim.tbl_extend("force", env.dev.Security.Auth.GAPI, tbl)
  fs.write_json(path, env)
end

local update_auth_data = function(tbl)
  local env = fs.read_json(http_client_private_path) or {}
  env.dev.Security.Auth.GAPI.auth_data = vim.tbl_extend("force", env.dev.Security.Auth.GAPI.auth_data, tbl)
  fs.write_json(http_client_private_path, env)
end

describe("oauth", function()
  local curl, system, wait_for_requests
  local http_buf
  local on_request, redirect_request
  local result = {}

  local function get_request(no)
    return system.log[no or 1] or {}
  end

  before_each(function()
    restore_http_client_files()
    curl = h.Curl.stub { ["https://www.secure.com"] = {} }

    stub(cmd.queue, "resume", function() end)

    stub(tcp, "server", function(host, port, callback)
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
        params.headers = system.args.cmd[8]
        params.url = system.args.cmd[#system.args.cmd]
        params.cmd = system.args.cmd

        system.async = true

        system.add_log(params)
        curl.request(system)

        vim.schedule(function()
          system.args.on_exit(system.completed)
        end)
      end,
    })

    wait_for_requests = function(requests_no, predicate)
      system:wait(3000, function()
        if curl.requests_no >= requests_no and (predicate == nil or predicate()) then return true end
      end)
    end

    kulala_config.setup { default_view = "body", debug = 1 }
    http_buf = h.create_buf(
      ([[
        ### Shared
        # @curl-verbose
        ###

        GET https://secure.com
        Authorization: Bearer {{$auth.token("GAPI")}}
      ]]):to_table(true),

      h.expand_path("requests/oauth.http")
    )
    h.send_keys("3j")
  end)

  after_each(function()
    h.delete_all_bufs()

    curl.reset()
    system.reset()
    on_request = nil

    _ = type(cmd.queue.resume) == "table" and cmd.queue.resume:revert()
    vim.ui.open:revert()
    tcp.server:revert()

    restore_http_client_files()
  end)

  teardown(function()
    restore_http_client_files(true)
  end)

  it("returns stored access token if it is not expired", function()
    update_auth_data { access_token = "stored_access_token", acquired_at = os.time(), expires_in = os.time() + 3600 }

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
    update_auth_data { id_token = "stored_id_token", acquired_at = os.time(), expires_in = os.time() + 3600 }

    kulala.run()
    wait_for_requests(1)

    assert.is.same("stored_id_token", get_auth_header())
  end)

  it("refreshes access token if it is expired", function()
    cmd.queue.resume:revert()

    curl.stub {
      ["https://token.url"] = { stdout = '{ "access_token": "refreshed_access_token"}' },
    }

    update_auth_data {
      access_token = "expired_access_token",
      acquired_at = os.time() - 10,
      expires_in = 1,
      refresh_token = "refresh_token",
      refresh_token_acquired_at = os.time(),
      refresh_token_expires_in = os.time() + 3600,
    }
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
      curl.stub {
        ["https://token.url"] = {
          stdout = '{ "access_token": "new_access_token", "refresh_token":"new_refresh_token"}',
        },
      }
      update_env { access_token = "expired_access_token" }
    end)

    it("grant type - Password", function()
      update_env { ["Grant Type"] = "Password" }

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

    describe("grant type - Client Credentinals", function()
      it("basic auth", function()
        cmd.queue.resume:revert()

        update_env {
          ["Grant Type"] = "Client Credentials",
          ["Client Credentials"] = "basic",
        }

        kulala.run()
        wait_for_requests(1)

        assert.has_properties(get_request(), {
          audience = "kulala_api",
          grant_type = "client_credentials",
          headers = "Authorization: Basic Y2xpZW50X2lkOmNsaWVudF9zZWNyZXQ",
          url = "https://token.url",
        })

        assert.has_properties(get_env(), {
          access_token = "new_access_token",
        })
        assert.near(os.time(), get_env().acquired_at, 1)

        assert.is.same("new_access_token", get_auth_header())
      end)

      it("in body auth", function()
        cmd.queue.resume:revert()

        update_env {
          ["Grant Type"] = "Client Credentials",
          ["Client Credentials"] = "in body",
        }

        kulala.run()
        wait_for_requests(1)

        assert.has_properties(get_request(), {
          audience = "kulala_api",
          client_id = "client_id",
          client_secret = "client_secret",
          grant_type = "client_credentials",
          url = "https://token.url",
        })

        assert.has_properties(get_env(), {
          access_token = "new_access_token",
        })
        assert.near(os.time(), get_env().acquired_at, 1)

        assert.is.same("new_access_token", get_auth_header())
      end)

      it("generate JWT - HS256", function()
        cmd.queue.resume:revert()

        update_env {
          ["Grant Type"] = "Client Credentials",
          ["Client Credentials"] = "jwt",
          JWT = {
            header = {
              alg = "HS256",
              typ = "JWT",
            },
            payload = {
              aud = "https://token.url",
              iat = 1746360495,
              exp = 1746360500,
              iss = "kulala-service-account",
              scope = "devstorage.read_only",
            },
          },
        }

        update_env({
          ["Client Secret"] = "client_secret_client_secret_client_secret_client_secret",
        }, true)

        kulala.run()
        wait_for_requests(1)

        assert.has_properties(get_request(), {
          audience = "kulala_api",
          grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
          url = "https://token.url",
          assertion = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL3Rva2VuLnVybCIsImV4cCI6MTc0NjM2MDUwMCwiaWF0IjoxNzQ2MzYwNDk1LCJpc3MiOiJrdWxhbGEtc2VydmljZS1hY2NvdW50Iiwic2NvcGUiOiJkZXZzdG9yYWdlLnJlYWRfb25seSJ9.y58lczQ-y660InDrAy8kLMJa-sIKtWAhIwq5Pa199gE",
        })

        assert.has_properties(get_env(), {
          access_token = "new_access_token",
        })
        assert.near(os.time(), get_env().acquired_at, 1)

        assert.is.same("new_access_token", get_auth_header())
      end)

      it("generate JWT - RS256", function()
        cmd.queue.resume:revert()

        update_env {
          ["Grant Type"] = "Client Credentials",
          ["Client Credentials"] = "jwt",
          private_key = "-----BEGIN PRIVATE KEY-----\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC5cHDxLOlZKpgT\nLNEF18AlQkxOHwYuP3VOuAeCxwCMlICSmfVRCzl5Zv+36fVTnvSF5tp1J46JI6jD\nM3WIE9UmjcRA13TVfzkoRuEKOfd20/PVEoxAXt4h5xgT4yuuJB1+C+R4xcZY4ul7\neCar1YJ12JJEt8vnZRGEhpjE8FtGvCBdDQ2+d7Qhr2LL8PIYW6mS6++5uCBAno+4\nevOmE2GkeQAfosrkDLSjOtNzF9pEYA5BzW1ZuZJJyWukUvaze4MqFH/6XfqzFPtr\n5XfQo8Olifljteic6JQx9KcvhXI7v1owtCpjkqcXMtiXtR23mRws0h//outYR0o4\nfJuOmouVAgMBAAECggEALJ/lXfRb1yxL2llvl4Na5tx0dlw65Yg5146rqAnxlOLr\nqdvI0A7ubsudgAmaEtxupYZvTcAOKexd4VOR1gRHx/ZXou72W6Y4//tGjmpypbLN\nu5myDI+HzwrInYiOa2KfgkSkX3fgimVYoHDChZlkwq0yTb0ZIX8N3yFww/u/S17y\n4sP3/+94dR6KWZTuufsmknAvByVGtVe3bGszYo77DC3m7+Kx2mR88anuP9a2H3Jf\nldzVCPvJ4bboncTFItxERRiHX/N7xwmNO7MzL5WZRL+GPe9+P/Hr/PKokeQc+yEg\n0cfWqKG0tyTLArRGOOHZ3wHLGuqjSFc+RZiXoL3dxQKBgQDwGSMjdhKa+Ck6SwkU\n26vvTLN5XTwleG9w5Mhj3esKs0DROEGfksFmSCCkFNboDl11RJuUldNwa4AVyZoc\nPbA96jRJGK7AEcNOV9FwdEs8rc0Berfn6klQuE66gsVonIM9fRiq8pYnnZ552Urh\nuHxgQoQL5iWCdl/IZ4kai8FHJwKBgQDFuI/Dv7HjFS9bOkIP7pg/KKYzl6VsUSlp\nEkd67V9TLHwIToq+k2cjmPMRCKD6KYkhbyOMN3GJpk348h9xdY9reIOBAb7hotbs\nQCRYFmuiksKeDoaP8N7MSIjs2C1AMO80RbyB2jLF8R9VIE64xZmUs0RBki5vqvtZ\naqQbpqxs4wKBgQCMbmd7Ckh/k76pddHt/T5nTPl8dugDEpo78dSzdM1RCN9UgA8C\nAphT9sQAtJ+uQxiuyl4lXiy5iGb2V2BoPDylOiMyzdkIRltxqzO5DowjBZTu1JRU\ndVhEekiyFmLYeRLaGB0hf5oLuclDg7CkrX8x3jXVr9son4wOb2BlwnBd6QKBgALs\nZKvHRNEPuiCGLv3fUD720eZHYrnERXF5RLdLlTI8oSTaTHDe6xJ6q3VgBElOnelx\npDvpgfNAEz0QD2j1DQbQxFj+9pyNdNIPbLoksri3pMsDeffc3t50YBnoZFrjnlXO\nhigBWujUVNtEXAWdXlT1hZfWmnsqMwcybXS/NSNzAoGBAJekqSCvUQHdiNWq1BPp\nM998rdujTGmfYCdKLT+c0i1/s3YuGu/h87tTSjXi7Jmq/iNVM2+RoTaGvvD1b+ZC\nGLcVcsqa6qD77WRQZ3q+2sF8v2vSd9oHT0R2jA4U/zVyF9dFOV4tT09xrFh7vLXM\nfYsrQTaSEta7ynoUI5/9NJTJ\n-----END PRIVATE KEY-----\n",
          JWT = {
            header = {
              alg = "RS256",
              typ = "JWT",
            },
            payload = {
              aud = "https://token.url",
              iat = 1746360495,
              exp = 1746360500,
              iss = "kulala-service-account",
              scope = "devstorage.read_only",
            },
          },
        }

        update_env({
          ["Client Secret"] = "client_secret_client_secret_client_secret_client_secret",
        }, true)

        kulala.run()
        wait_for_requests(1)

        assert.has_properties(get_request(), {
          audience = "kulala_api",
          grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
          url = "https://token.url",
          assertion = "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJodHRwczovL3Rva2VuLnVybCIsImV4cCI6MTc0NjM2MDUwMCwiaWF0IjoxNzQ2MzYwNDk1LCJpc3MiOiJrdWxhbGEtc2VydmljZS1hY2NvdW50Iiwic2NvcGUiOiJkZXZzdG9yYWdlLnJlYWRfb25seSJ9.Q4G8JrXHIswxKMRu7QVEzTCGi5kL_EksoQjDGwOIBdU_Lc2XtrB0NOVhBIKPtKfkiWPlfdNBqsg1KMlfGGDFn7Ge1yARn97JELWyZN1TxCLuncyBgLxiwr8v9f1meX-Vj-Fj7DQQdgSQfBR3w0TDO74CDdtqRCozQFNudsrrVOnBgjutyQmwJeoICJTIN89Uk9RP2rkWDQES7bH2EZ4kDRqRFVTTi8N7bU4veGHlO0wYr4OB7nLclTDwzcwhL1Mzrv9wLYpDxDhbffwjVz8ZmfWBgUQFTaw_MxBOYq4Q5yhYPXLswH-NuFPDIFviKlbXJrkjARfOa3ghlKmuulTHtA",
        })

        assert.has_properties(get_env(), {
          access_token = "new_access_token",
        })
        assert.near(os.time(), get_env().acquired_at, 1)

        assert.is.same("new_access_token", get_auth_header())
      end)

      it("use provided assertion", function()
        cmd.queue.resume:revert()

        update_env {
          ["Grant Type"] = "Client Credentials",
          ["Client Credentials"] = "jwt",
          Assertion = "custom_assertion",
        }

        kulala.run()
        wait_for_requests(1)

        assert.is_true(#get_request().assertion > 0)
        assert.has_properties(get_request(), {
          audience = "kulala_api",
          grant_type = "urn:ietf:params:oauth:grant-type:jwt-bearer",
          url = "https://token.url",
        })

        assert.has_properties(get_env(), { access_token = "new_access_token" })
        assert.near(os.time(), get_env().acquired_at, 1)

        assert.is.same("new_access_token", get_auth_header())
      end)
    end)

    it("grant type - Implicit", function()
      cmd.queue.resume:revert()

      update_env { ["Grant Type"] = "Implicit" }
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

      -- Saves new access token
      assert.is.same("new_access_token", get_auth_header())
      assert.has_properties(get_env(), {
        access_token = "new_access_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)
    end)

    it("grant type - Authorization code", function()
      cmd.queue.resume:revert()

      update_env { ["Grant Type"] = "Authorization Code" }
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
      cmd.queue.resume:revert()

      curl.stub {
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
      }
      update_env { ["Grant Type"] = "Device Authorization", ["Device Auth URL"] = "https://device.url" }
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
      assert.near(os.time(), get_env().acquired_at, 5)

      -- Opens browser with the verification URL and copies the user code to clipboard
      assert.is.same("verification_url", result.url_params.url)
      -- assert.is.same("new_user_code", vim.fn.getreg("+"))

      -- Sends request to Token URL
      assert.has_properties(get_request(2), {
        url = "https://token.url",
        audience = "kulala_api",
        client_id = "client_id",
        client_secret = "client_secret",
        device_code = "new_device_code",
        grant_type = "urn:ietf:params:oauth:grant-type:device_code",
      })

      -- Saves new access token
      assert.has_properties(get_env(), {
        access_token = "new_access_token",
      })
      assert.near(os.time(), get_env().acquired_at, 1)

      assert.is.same("new_access_token", get_auth_header())
    end)

    it("adds custom response_type to Auth request", function()
      update_env { ["Grant Type"] = "Authorization Code", ["Response Type"] = "code token" }
      redirect_request = "code=auth_code&state=state"

      kulala.run()
      wait_for_requests(1)

      assert.has_properties(result.url_params, {
        response_type = "code token",
      })
    end)

    describe("adds PKCE params to Auth request", function()
      it("adds PKCE params to Auth request from config", function()
        update_env {
          ["Grant Type"] = "Authorization Code",
          PKCE = {
            ["Code Verifier"] = "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM",
            ["Code Challenge Method"] = "S256",
          },
        }
        redirect_request = "code=auth_code"

        kulala.run()
        wait_for_requests(1)

        assert.is_true(#result.url_params.code_challenge > 0)
        assert.is.same("S256", result.url_params.code_challenge_method)

        assert.has_properties(get_request(), {
          code_verifier = "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM",
        })
      end)

      it("adds PKCE params to Auth request calculated", function()
        update_env {
          ["Grant Type"] = "Authorization Code",
          PKCE = true,
        }
        redirect_request = "code=auth_code&state=state"

        kulala.run()
        wait_for_requests(1)

        assert.is_true(#result.url_params.code_challenge > 0)
        assert.is.same("S256", result.url_params.code_challenge_method)

        assert.is_true(#get_request().code_verifier > 0)
      end)
    end)

    describe("adds Client Credentials params to requests", function()
      it("in headers", function()
        update_env {
          ["Grant Type"] = "Authorization Code",
          ["Client Credentials"] = "basic",
        }
        redirect_request = "code=auth_code&state=state"

        kulala.run()
        wait_for_requests(1)

        assert.has_string(get_request().headers, "Authorization: Basic")
      end)

      it("in body", function()
        update_env {
          ["Grant Type"] = "Authorization Code",
          ["Client Credentials"] = "in body",
        }
        redirect_request = "code=auth_code&state=state"

        kulala.run()
        wait_for_requests(1)

        assert.has_properties(get_request(), {
          client_id = "client_id client_id",
          client_secret = "client_secret client_secret",
        })
      end)
    end)

    it("adds custom params to requests", function()
      update_env {
        ["Grant Type"] = "Authorization Code",
        ["Expires In"] = 3500,
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
      }
      redirect_request = "code=auth_code&state=state"

      kulala.run()
      wait_for_requests(1)

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

      assert.has_properties(get_env(), {
        code = "auth_code",
        expires_in = 3500,
      })
    end)

    it("takes into account curl flags", function()
      update_env { ["Grant Type"] = "Password" }

      kulala_config.options.additional_curl_options = { "--location" }

      kulala.run()
      wait_for_requests(1)

      assert.is_true(vim.tbl_contains(get_request().cmd, "--location"))
      assert.is_true(vim.tbl_contains(get_request().cmd, "--verbose"))
      assert.is_true(vim.tbl_contains(get_request().cmd, "--insecure"))
    end)
  end)

  it("revokes token", function()
    curl.stub { ["http://revoke.url"] = { stdout = "{}" } }
    update_env { ["Revoke URL"] = "http://revoke.url" }
    update_auth_data {
      access_token = "expired_access_token",
      acquired_at = os.time(),
      expires_in = 1,
      refresh_token = "refresh_token",
      refresh_token_acquired_at = os.time(),
      refresh_token_expires_in = os.time() + 3600,
    }

    kulala.open()
    oauth.revoke_token("GAPI")

    wait_for_requests(1, function()
      return get_request().url == "http://revoke.url"
    end)

    -- assert.has_properties(get_request(), {
    --   token = "expired_access_token",
    --   url = "http://revoke.url",
    -- })
    -- assert.same({}, get_env())
  end)
end)
