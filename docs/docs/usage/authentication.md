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

Basic, Digest, NTLM, Negotiate, Bearer Token,
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

Futhermore you can enter username and password in
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
# @name login
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

with the request variables feature from Kulala you
can now access the `access_token` and use it in the next requests.

```http
GET {{apiURL}}/items HTTP/1.1
Accept: application/json
Authorization: Bearer {{login.response.body.$.access_token}}
```

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
