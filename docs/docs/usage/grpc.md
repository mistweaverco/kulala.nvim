# gRPC

- You can make gRPC requests in Kulala just as you would make HTTP requests.

## Usage

### Dependencies

Ensure you have `grpcurl` installed to use this feature. You can find it here: [gRPCurl](https://github.com/fullstorydev/grpcurl).

### Making a gRPC Request

To make a gRPC request, use the following format:

```http
# @grpc-global-flags
# @grpc-flags
GRPC flags address command service.method
```

For example:

```http
# @grpc-global-import-path ../protos 
# @grpc-global-proto helloworld.proto
GRPC localhost:50051 helloworld.Greeter/SayHello
Content-Type: application/json

{"name": "world"}

###

# @grpc-plaintext
GRPC localhost:50051 describe helloworld.Greeter

###

# @grpc-v
GRPC localhost:50051 list
# service.method is optional when using a command list|describe

###

# @grpc-protoset my-protos.bin
GRPC helloworld.Greeter/SayHello
# address is optional when using proto files
```

### Flags

Flags can be set through metadata either locally per request or globally per buffer. Use the following formats:

- Local flags: `@grpc-..` apply for current request only.
- Global flags: `@grpc-global-..` apply for all requests in the buffer. Global settings will persist until the buffer is closed or globals are cleared with `<leaderRx>`.

### Variables

Just as with HTTP requests, you can use variables in gRPC requests. For example:

```http
@address=localhost:50051
@service=helloworld.Greeter
@flags=-import-path ../protos -proto helloworld.proto  -- [!] flags must be prefixed with `-`
GRPC {{flags}} {{address}} {{service}}/SayHello
Content-Type: application/json

< /path/to/file.json
```

:::warning

Flags set in variables override flags set in metatadata, which in turn override global flags.

:::
