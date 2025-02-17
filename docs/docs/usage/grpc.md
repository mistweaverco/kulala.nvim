# GRPC

- You can make GRPC requests in Kulala just as you would do HTTP requests.

## Usage

### Dependencies

Ensure you have `grpcurl` installed to use this feature. You can find it here: [grpcurl](https://github.com/fullstorydev/grpcurl).

### Making a GRPC Request

To make a GRPC request, use the following format:

```http
# @grpc-global-flags
# @grpc-flags
GRPC address command service.method
```

e.g.,

```http
# @grpc-global-import-path ../protos 
# @grpc-global-proto helloworld.proto
GPRC localhost:50051 helloworld.Greeter/SayHello
Content-Type: application/json

{"name": "world"}

###

# @grpc-plaintext
GRPC localhost:50051 describe helloworld.Greeter

###

# @grpc-v
GPRC localhost:50051 list
# service.method is optional when using a command list|describe

###

# @grpc-protoset my-protos.bin
GRPC helloworld.Greeter/SayHello
# address is optional when using proto files
```

### Flags

Flags can be set through metadata either locally per request or globally per buffer. Use the following formats:

- Local flags: `@grpc-..` apply for current request only
- Global flags: `@grpc-global-..` apply for all requests in the buffer
```
