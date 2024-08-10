# Authentication

How to handle authentication in Kulala.

In general, you can use the `Authorization` header to send an authentication token to the server.
The content of the header depends on the type of authentication you are using.

See these topics for more information:

- [Sending form data](sending-form-data.md)
- [Dynamic environment variables](dynamically-setting-environment-variables-based-on-response-json.md)
- [Dotenv and environment files](dotenv-and-http-client.env.json-support)
- [Request variables](request-variables.md)

## Basic Authentication

Basic authentication needs a Base64 encoded string of `username:password` as the value of the `Authorization` header.

If given it will be directly used in the HTTP request:

```http
GET https://www/api HTTP/1.1
Authorization: Basic TXlVc2VyOlByaXZhdGU=
```

Futhermore you can enter username and password in plain text in the `Authorization` header field, Kulala will automatically encode it for you.
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
Authorization: Basic {{Username}}:{{Password}}
```

or `username password`

```http
GET https://www/api HTTP/1.1
Authorization: Basic {{Username}} {{Password}}
```

## NTLM Authentication

For NTLM authentication, you need to provide the username and password the same way:

```http
GET https://www/api HTTP/1.1
Authorization: Basic {{Username}}:{{Password}}
```

or

```http
GET https://www/api HTTP/1.1
Authorization: Basic {{Username}} {{Password}}
```

## Negotiate

This is a SPNEGO-based implementation, which does not need username and password but uses the default credentials.

```http
GET https://www/api HTTP/1.1
Authorization: Negotiate
```

## Bearer Token

For a Bearer Token you need to send your credentials to an authentication endpoint and receive a token in return.
This token is then used in the `Authorization` header for further requests.

### Sending the credentials

```http
# @name login
POST {{loginURL}} HTTP/1.1
Content-Type: application/x-www-form-urlencoded
Accept: application/json

client_id={{ClientId}}&client_secret={{ClientSecret}}&grant_type=client_credentials&scope={{Scope}}
```

This is a `login` named request with the credentials and the result may look like

```json
{
  "token_type": "Bearer",
  "expires_in": 3599,
  "access_token": "eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1Ni....."
}
```

with the request variables feature from Kulala you can now access the `access_token` and use it in the next requests.

```http
GET {{apiURL}}/items HTTP/1.1
Accept: application/json
Authorization: Bearer {{login.response.body.$.access_token}}
```
