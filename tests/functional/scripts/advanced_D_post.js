// https://www.jetbrains.com/help/idea/http-response-reference.html#request-properties

const someHeaderValue = response.headers.valueOf("Server");
if (someHeaderValue) {
  client.log({ someHeaderValue });
}
