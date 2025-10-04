# Using Variables

You can use variables in your HTTP requests.

## Basic document variables

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"
@pokemon=pikachu
@pokemon2=bulbasaur

GET https://pokeapi.co/api/v2/pokemon/{{pokemon}} HTTP/1.1
Accept: application/json

###

GET https://pokeapi.co/api/v2/pokemon/{{pokemon2}} HTTP/1.1
Accept: application/json
```

These variables are available in all requests in the file.

## Prompt variables

You can also use prompt variables.
These are variables that you can set when you run the request.

```http title="examples.http"
# @prompt pokemon
# @secret password
GET https://pokeapi.co/api/v2/pokemon/{{pokemon}} HTTP/1.1
Accept: application/json
```

When you run this request,
you will be prompted to enter a value for `pokemon`.

These variables are available for the current request and
all subsequent requests in the file.

## Variables scope

By default, variables are scoped to the entire document, i.e., they are available in all requests in the file, 
no matter where they are declared and later declarations will override earlier ones.

You can change the scope to `variables_scope = "request"` in the options, which will make variables scoped to the current request only.
