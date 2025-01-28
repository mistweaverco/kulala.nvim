// https://www.jetbrains.com/help/idea/http-response-reference.html#request-properties
const url = new URL(request.url.tryGetSubstituted());
const method = request.method;
const params = url.searchParams;
const unix_timestamp = 125000;
const token_raw = request.variables.get('TOKEN_RAW');
const key1 = params.get('key1');
const computed_token = `${method}${token_raw}${key1}${unix_timestamp}`;

// Either use request.variables.set which is only valid for the current request
// or use client.global.set("COMPUTED_TOKEN", computed_token) to store the value globally
// and persist it across restarts
request.variables.set('COMPUTED_TOKEN', computed_token);
const contentTypeHeader = request.headers.findByName('Content-Type');

if (contentTypeHeader) {
  client.log("Content-Type:" + contentTypeHeader.getRawValue());
}
