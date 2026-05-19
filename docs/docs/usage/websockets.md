# Websockets

- You can make persistent connections to a websocket server in Kulala just as you would make HTTP requests.

## Usage

### Dependencies

WebSocket connections use the native client built into
[kulala-core](https://github.com/mistweaverco/kulala-core)
(no `websocat` binary required).

### Establishing a websocket connection

To establish a websocket connection, use the following format:

```http
WS wss://echo.websocket.org

{ "name": "world" }
```

If there is a body in the request,
it'll be sent upon connection to the server.

### Receiving messages

Received messages will be displayed in the buffer, prefixed with `=>`.

### Sending messages

To send messages to the server, simply type the message and press `<CR>`.

### Closing the connection

To close the connection, press `<C-c>`.
