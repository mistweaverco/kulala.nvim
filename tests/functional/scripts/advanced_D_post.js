// https://www.jetbrains.com/help/idea/http-response-reference.html#request-properties

const someHeaderValue = response.headers.valuesOf('Server');
if (someHeaderValue) {
  client.log({ someHeaderValue });
}
