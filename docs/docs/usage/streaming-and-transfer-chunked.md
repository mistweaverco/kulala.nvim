# Streaming and Transfer-Encoding: chunked

- Kulala can process `Transfer-Encoding: chunked` and streamed responses.

## Usage

To instruct Kulala to process a response as a stream, you need to set the `@accept chunked` metadata on the request.

```http
# @accept chunked
POST https://httpbin.org/index HTTP/1.1
```

