# Scripts request reference

These helper functions are available in the request object in scripts.

## request.variables.get

Get a request variable.

Request variables are only available for the duration of the request.

```javascript
client.log(request.variables.get("SOME_TOKEN"));
```

## request.variables.set

Set a request variable.

Request variables are only available for the duration of the request.

```javascript
request.variables.set("SOME_TOKEN, "123");
client.log(request.variables.get("SOME_TOKEN"));
```

## request.body.getRaw

Returns the request body in the raw format:

If the body contains variables,
their names are displayed instead of their values.
For example:

```javascript
client.log(request.body.getRaw());
```

## request.body.tryGetSubstituted

Returns the request body with variables substituted.

```javascript
client.log(request.body.tryGetSubstituted());
```

## request.environment.get


Retrieves a value of the environment variable identified
by its name or returns null if it doesn't exist.

```javascript
client.log(request.environment.get("SOME_ENV_VAR"));
```

## request.headers.all

Returns all request header objects.

Each header object has the following methods:

- `name()` - Returns the name of the header.
- `getRawValue()` - Returns the value of the header in the raw format.
- `tryGetSubstituted()` - Returns the value of the header with variables substituted.

```javascript
const headers = request.headers.all();
for (const header of headers) {
  client.log(header.name());
  client.log(header.getRawValue());
  client.log(header.tryGetSubstituted());
}
```

## request.headers.findByName

Returns a request header object identified by its name.

The header object has the following methods:

- `name()` - Returns the name of the header.
- `getRawValue()` - Returns the value of the header in the raw format.
- `tryGetSubstituted()` - Returns the value of the header with variables substituted.

```javascript
const contentTypeHeader = request.headers.findByName("Content-Type");
if (contentTypeHeader) {
  client.log(contentTypeHeader.name());
  client.log(contentTypeHeader.getRawValue());
  client.log(contentTypeHeader.tryGetSubstituted());
}
```

## request.method

Returns the request method.

Such as `GET`, `POST`, `PUT`, `DELETE`, etc.

```javascript
client.log(request.method());
```

## request.url.getRaw

Returns the request URL in the raw format, without any substitutions.

```javascript
client.log(request.url.getRaw());
```

## request.url.tryGetSubstituted

Returns the request URL with variables substituted.

```javascript
client.log(request.url.tryGetSubstituted());
```
