# Shared Blocks

Shared blocks can be used to share variables, metadata, scripts and requests between multiple requests. 

To declare a shared block, use the `### Shared` or `### Shared each` request name for the `first` request in the document.

Shared variables and metadata will apply to all requests that follow the shared block.  
Variables and metadata declared in a request will shadow shared variables and metadata.

Scripts and requests declared in the shared block and called with `run` command will be executed before the request you run.

## `### Shared` block

-  When executing `run request`, the shared scripts and requests will be executed before the request you run.
-  When executing `run all requests`, the shared scripts and requests will be executed `once` before all requests.

## `### Shared each` block

-  When executing `run request`, the shared scripts and requests will be executed before the request you run.
-  When executing `run all requests`, the shared scripts and requests will be executed before `each` request.

## Variable Scope

By default variables are scoped to `document`, which means they are shared across all requests in the document 
and later declarations will override previous ones, including the ones in shared blocks.

You can change the scope to `variables_scope = "request"` in the options, which will make variables scoped to the current request only 
and shared variables will not be overridden by request variables.

```http
### Shared

@shared_var_1 = shared_value_1
@shared_var_2 = shared_value_2

# @curl-connect-timeout 20
# @curl-location

run ./login.http

< {%
  console.log("pre request 0");
%}

< ./pre_request.js

POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json

{
  "shared_var_1": 1,
  "shared_var_2": 2
}

> ./post_request.js

> {%
  console.log("post request 0");
%}


### request 1

@local_var_1 = local_value_1
@shared_var_2 = local_value_2

# @curl-connect-timeout 10

POST https://httpbin.org/post HTTP/1.1
Content-Type: application/json

{
  "shared_var_1": 3,
  "shared_var_2": 4
}
```
