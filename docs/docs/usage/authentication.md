# Authentication

How to handle authentication in Kulala.

In general, you can use the `Authorization` header to
send an authentication token to the server.
The content of the header depends on the type of authentication you are using.

See these topics for more information:

- [Sending form data](sending-form-data.md)
- [Dynamic environment variables][dyn-env]
- [Dotenv and environment files](dotenv-and-http-client.env.json-support)
- [Request variables](request-variables.md)

## Supported Authentication Types

Amazon Web Services (AWS) Signature version 4 is
a protocol for authenticating requests to AWS services.

New Technology LAN Manager (NTLM),
is a suite of Microsoft security protocols that
provides authentication, integrity, and confidentiality to users.

Basic, Digest, NTLM, Negotiate, Bearer Token, OAuth 2.0,
AWS Signature V4 and SSL Client Certificates are supported.

## Basic Authentication

Basic authentication needs a
Base64 encoded string of `username:password` as
the value of the `Authorization` header.

If given it'll be directly used in the HTTP request:

```http
GET https://www/api HTTP/1.1
Authorization: Basic TXlVc2VyOlByaXZhdGU=
```

Furthermore you can enter username and password in
plain text in the `Authorization` header field,
Kulala will automatically encode it for you.

There will be two possible ways to enter the credentials:

```http
GET https://www/api HTTP/1.1
Authorization: Basic {{Username}}:{{Password}}
```

or

```http
GET https://www/api HTTP/1.1
Authorization: Basic {{Username}} {{Password}}
```

## Digest Authentication

Digest is implemented the same way as Basic authentication. 

You can enter the `username:password` in plain text

```http
GET https://www/api HTTP/1.1
Authorization: Digest {{Username}}:{{Password}}
```

or `username password`

```http
GET https://www/api HTTP/1.1
Authorization: Digest {{Username}} {{Password}}
```

## Web-browser based authentication

Below is an example of how to simulate a web-browser based authentication with CSRF protection:

```http
### Acquire_XSRF_TOKEN

GET localhost:8000/login

> {%
  -- lua
  client.global.token = response.cookies["XSRF-TOKEN"].value
  client.global.decoded_token = vim.uri_decode(client.global.token)
  client.global.session = response.cookies["laravel_session"].value
%}

### Authentication

POST localhost:8000/login
Content-Type: application/json
X-Xsrf-Token: {{decoded_token}}
Cookie: XSRF-TOKEN={{token}}
Cookie: laravel_session={{session}}
Referer: http://localhost:8000/login

{
  "email": "mail@mail.com",
  "password": "passpass"
}

> {%
  -- lua
  -- save the new set authenticated session
  client.global.session = response.cookies["laravel_session"].value
%}

### Dashboard

run #Acquire_XSRF_TOKEN
run #Authentication

GET http://localhost:8000/dashboard
Cookie: laravel_session={{session}}
```

## NTLM Authentication

For NTLM authentication,
you need to provide the username and password the same way:

```http
GET https://www/api HTTP/1.1
Authorization: NTLM {{Username}}:{{Password}}
```

or

```http
GET https://www/api HTTP/1.1
Authorization: NTLM {{Username}} {{Password}}
```

or without any username where the current user is been used

```http
GET https://www/api HTTP/1.1
Authorization: NTLM
```

## Negotiate

This is a SPNEGO-based implementation,
which doesn't need username and password,
but uses the default credentials.

```http
GET https://www/api HTTP/1.1
Authorization: Negotiate
```

## Bearer Token

For a Bearer Token you need to send your credentials to
an authentication endpoint and receive a token in return.

This token is then used in the `Authorization` header for further requests.

### Sending the credentials

```http
### login
POST {{loginURL}} HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: application/json

client_id={{ClientId}}&client_secret={{ClientSecret}}&grant_type=client_credentials&scope={{Scope}}
```

This is a `login` named request with the credentials and
the result may look like

```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1Ni....."
}
```

With the request variables feature from Kulala you
can now access the `access_token` and use it in the next requests.

```http
GET {{apiURL}}/items HTTP/1.1
Accept: application/json
Authorization: Bearer {{login.response.body.$.access_token}}
```

## OAuth 2.0 Authorization

Kulala supports OAuth 2.0 authorization for Grant Types: `Authorization Code`, `Client Credentials`, `Device Authorization`, `Implicit and Password`.

You can get/refresh an access token and authenticate your request to OAuth 2.0 protected resources. 
To let you enter the user credentials, Kulala will launch your default browser and will intercept  access tokens automatically if the redirect URL is set to localhost.

A typical flow includes the following steps:

1. Specify authentication settings, such as the grant type and token URL, in JSON format in a public environment file `http-client.env.json`.

2. Refer to this authentication configuration in your HTTP requests using the `$auth.token` variable.

3. Run the request. If authentication is successful, you will access the protected resource. You can check the received access token, refresh token and other authentication details in the `auth_data` section of `http-client.prrivate.env.json` file.

4. You can also manually revoke and refresh the access token or re-initialize the authentication procedure by requesting a new token.

### Create authentication configuration

You can manually create an authentication configuration in the `http-client.env.json` file or use Kulala Authentication Manager to create it for you. 

1. Press `<leader>Ru` to open the Authentication Manager, then press `a` to add a new authentication configuration.

This will create a configuration template for the authentication configuration in the `http-client.env.json` file, under the current environment.  

If you need to change the environment, use `<leader>Re` to open the Environment Manager and select the environment you want to use. The environment file will be 
searched for upwards from the folder of the current buffer. If no environment file is found, it will be created in the current folder.

```json
{
  "dev": {
      "Security": {
        "Auth": {
          "auth-id": {
            "Type": "OAuth2",
            "Grant Type": "",
            "Client ID": ""
              ...
          }
        }
      }
    }
}
```

Replace the placeholder `auth-id` with a meaningful name that you will use to refer to this configuration in your .http file.

Specify the authentication parameters. The required parameters depend on the selected "Grant Type". Remove unnecessary parameters from the template.

2. To edit `http-client.env.json` file, press `e` in the Authentication Manager. Press `p` for `http-client.private.env.json` file and press `m` to remove the authentication configuration.

:::info

It is recommended to store public authentication variables in the `http-client.env.json` file and private authentication variables, like `Client Secret`,  in the `http-client.private.env.json` file. 
Auth configurations from both files get merged during authentications.

Kulala will also use `http-client.private.env.json` file to store authentication data, such as access token, refresh token, and expiration time.

:::

### Use authentication configuration in HTTP requests

Once an authentication configuration is created, you can use it to get an access token and authenticate your requests.

Pass the name of an authentication configuration to the `{{$auth.token()}}` variable, for example, `{{$auth.token("my-config")}}`. You can use this variable in the request Authorization header or in query parameters.

```http
POST {{loginURL}} HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Authorization: Bearer {{$auth.token("auth-id")}}
Accept: application/json
```

Execute the request. Before accessing the protected resource, Kulala will open your default browser and send a request to the authorization server to obtain an access token.

When prompted, complete the authentication process. The browser will be redirected to the provided `Redirect URL`. 

Kulala will intercept this redirect and extract the authorization details from the URL, if the provided  Redirect URL is `localhost` or `127.0.0.1`. Otherwise, you need to manually copy the code from the redirect URL and paste it into Kulala prompt. 

For Grant Type `Device Authorization`, the code will be copied into clipboard, to be pasted into consent form.

If the authentication is successfully completed, Kulala will access the protected resource and the authentication details, such as access token, refresh token, and expiration time, will be saved in the `http-client.private.env.json` file.

### Manually acquire access token

When you refer to an authentication configuration in an HTTP request, Kulala automatically gets (or refreshes) an access token before accessing the protected resource. 
If you want to get an access token without sending an actual request to the protected resource, you can acquire the access token manually.

Open then Authentication Manager by pressing `<leader>Ru` and select the authentication configuration you want to use, then press `g` to acquire a new 
token or `r` to refresh the existing one.

### Revoke an access token

You can revoke an access token by pressing `r` in the Authentication Manager. This will revoke the access token with the provider and remove authentication data 
from the `http-client.private.env.json` file.

### Use ID token instead of access token

If your server requires the use of an ID token instead of an access token, you can configure Kulala to do this in any of the following ways:

In your authentication configuration, use the `"Use ID Token": true` parameter.

In an .http file, use the `$auth.idToken` variable, for example, `Authorization: Bearer {{$auth.idToken("auth-id-1")}}`.

### Use custom authentication parameters

Kulala provides an option to define custom request parameters that your authorization server may require. This includes, for example, resource and audience that 
extend the OAuth 2.0 Authorization framework.

In your authentication configuration, add the `"Custom Request Parameters"` object.

Inside `"Custom Request Parameters"`, enter your parameter name and value (a string or an array).

If you want to restrict the parameter usage to certain requests, define the value as an object with two keys:

"Value" (parameter value)

"Use" — The scope for using the parameter. It has three possible values:

 - "Use": "Everywhere" (in any request)
 - "Use": "In Auth Request" (use in authentication requests only)
 - "Use": "In Token Request" (use in token requests only)

For example:

```json
"auth-id-1": {
"Type": "OAuth2",
  "Custom Request Parameters": {
    "audience": {
      "Value": "https://my-audience.com/",
      "Use": "In Token Request"
    },
    "resource": [
      "https://my-resource/resourceId1",
      "https://my-resource/resourceId2"
    ],
    "my-custom-parameter": "my-custom-value"
  },
}
```

:::info

If you need to set custom curl flags for authentication requests, e.g., `--insecure` to skip secure connection verification - you can do this 
with `# @curl-global-..` flags in your .http file or by setting `additional_curl_options` in Kulala's config.

:::

### Authentication configuration parameters

#### Type

Authentication type. Possible values:

"OAuth2": authenticate your request using OAuth2.

#### Grant Type

Method to get access tokens. Possible values: "Authorization Code", "Client Credentials", "Device Authorization", "Implicit", and "Password".

#### Auth URL

Authorization URL to which the application will redirect the client request to get the auth code. 

"Auth URL" is required for Authorization Code and Implicit grant types.

#### Token URL

The provider's authentication server, to exchange an authorization code for an access token. 

"Token URL" is required for Authorization Code, Client Credentials, Device Authorization, and Password grant types.

#### Redirect URL

Client application callback URL to which the request should be redirected after authentication. 

This can be a URL from your client application settings, or, if the authorization server accepts any URL, use http://localhost:1234.

#### Revoke URL

The URL to revoke the access token. This is optional and can be used to revoke the access token with the provider.

#### Client ID

Public identifier of your client registered with the API provider. The parameter is required for all grant types.

#### Client Secret

Confidential identifier used by a client application to authenticate to an authorization server. 

The parameter is required for the Client Credentials grant type.

#### Device Auth URL

The URL to which the client device makes a request in order to obtain the device code and user code.

Applicable and required for the Device Authorization grant type.

#### Response Type

The type of response to be returned by the authorization server. This value is optional and will be added to the request URL automatically - `code` for 
Authorization Code and `token` for Implicit grant types. 

However, you can specify it manually if you need to use a different value or several, like `id_token token`.

#### Client Credentials

Enter one of the following:

- "none" if you do not want to specify client credentials in the request.

- "in body" if you want to send client credentials in the request body.

- "basic" to send a Basic authentication request in the request header (default value).

- "jwt" to send a JWT token in the request body.

#### PKCE

Enables Proof Key for Code Exchange (PKCE). Applicable with the Authorization Code grant type.

Enter "PKCE": true to use the default algorithm (S256 hashing the auto generated code verifier). Or customize the behavior using "Code Challenge Method" (plain or S256) 
and "Code Verifier". For example:

```json
"PKCE": {
    "Code Challenge Method": "Plain", 
    "Code Verifier": "YYLzIBzrXpVaH5KRx86itubKLXHNGnJBPAogEwkhveM"
},
```
#### Assertion

For Grant Type `Client Credentials` with JWT token to authenticate the request. You can provide the JWT token in this field.

#### JWT

If you would like for JWT token to be generated automatically, you can provide the details in the `JWT` object.

For algorithm, `RS256` you also need to provide `private_key` in the `http-client.private.env.json` file, for `HS256` the `Client Secret` is used.

Fields `exp` and `iat` are optional. If not provided, they will be calculated automatically (iat = current time, exp = iat + 50 seconds).

```json
"JWT": {
    "Header": {
      "alg": "RS256", -- or "HS256"
      "typ": "JWT"
    },
    "Payload": {
      "exp": 3600
      "iat": 17540,
    }
}
```

:::info

If you would like to build a JWT token manually or generate PKCE challenge/verifier , you can use built-in library in Lua request scripts:

```lua
local crypto = require("kulala.cmd.crypto")

---@class JWTPayload
---@field iss? string Issuer
---@field sub? string Subject
---@field scope? string Scope
---@field aud? string Audience
---@field exp? number Expiration time (in seconds since epoch)
---@field iat? number Issued at (in seconds since epoch)

---Generate a JWT token
---@param header {alg: string, typ: string} JWT header alg: "RS256"|"HS256", typ: "JWT"
---@param payload JWTPayload JWT payload
---@param key string Signing key
---@return string|nil JWT token
M.jwt_encode = function(header, payload, key)

---Generate a random PKCE verifier
---@return string|nil PKCE verifier
M.pkce_verifier = function()


---Generate a PKCE challenge from the verifier
---@param verifier string PKCE verifier
---@param method string PKCE method "Plain"|"S256" (default: "S256")
---@return string|nil PKCE challenge
M.pkce_challenge = function(verifier, method)
```

:::

#### Scope

A scope to limit an application's access to a user's account. Possible values depend on the service you are trying to access.

#### Expires In

If your auth provider does not return the `expires_in` field, a default value of `10` seconds will be set.  Otherwise, you can specify it manually in seconds.

#### Acquire Automatically

By default, Kulala refreshes or acquires an access token automatically before sending the request. 

Enter `"Acquire Automatically": false` if you do not want to automatically 
refresh or acquire an access token before sending the request. You can refresh or acquire manually.

#### Username

The username sent as part of authorization, used with the Password grant type.

#### Password

The user's password sent as part of authorization, used with the Password grant type.

#### Custom Request Parameters

Specify custom request parameters

## AWS Signature V4

Amazon Web Services (AWS) Signature version 4 is a
protocol for authenticating requests to AWS services.

AWS Signature version 4 authenticates requests to AWS services.
To use it you need to set the Authorization header schema to
AWS and provide your AWS credentials separated by spaces:

```plaintext
<access-key-id>: AWS Access Key Id
<secret-access-key>: AWS Secret Access Key
token:<aws-session-token>: AWS Session Token - required only for temporary credentials
region:<region>: AWS Region
service:<service>: AWS Service
```

```http
GET {{apiUrl}}/ HTTP/1.1
Authorization: AWS <access-key-id> <secret-access-key> token:<aws-session-token> region:<region> service:<service>
```

## SSL Client Certificate

This is described in the configuration section and is done on a per-host basis.

Example:

```lua
{
"mistweaverco/kulala.nvim",
  opts = {
    certificates = {
      ["localhost"] = {
        cert = vim.fn.stdpath("config") .. "/certs/localhost.crt",
        key = vim.fn.stdpath("config") .. "/certs/localhost.key",
      },
      ["www.somewhere.com:8443"] = {
        cert = "/home/userx/certs/somewhere.crt",
        key = "/home/userx/certs/somewhere.key",
      },
    },
  },
}
```

[dyn-env]: dynamically-setting-environment-variables-based-on-response-json.md

## Disable certificate verification

For development purposes, you may have a host with self-signed or expired certificates. If you trust this host, you can disable verification of its certificate.

In the http-client.private.env.json file, add `verifyHostCertificate": false` to the SSLConfiguration object. For example:

```json
{
    "dev": {
        "SSLConfiguration": {
            "verifyHostCertificate": false
        }
    }
}
```

If you run a request with this environment, the certificate verification will be disabled. 

This is equivalent to setting `--insecure` flag in `additional_curl_options` in the config file or with `# @curl-global-insecure` in the request.
