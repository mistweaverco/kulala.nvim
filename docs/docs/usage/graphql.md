# GraphQL

You can use the `GRAPHQL` method, `@graphql` directive or `X-REQUEST-TYPE: GraphQL` header to send GraphQL requests.

Create a file with the `.http` extension and write your GraphQL requests in it.

## With variables

```http title="gql-with-variables.http"
GRAPHQL https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
Accept: application/json
X-REQUEST-TYPE: GraphQL

query Person($id: ID) {
  person(personID: $id) {
    name
  }
}

{ "id": 1 }
```

## Without variables

```http title="gql-without-variables.http"
# @graphql
POST https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
Accept: application/json
X-REQUEST-TYPE: GraphQL

query Query {
  allFilms {
    films {
      title
      director
      releaseDate
      speciesConnection {
        species {
          name
          classification
          homeworld {
            name
          }
        }
      }
    }
  }
}
```
## Download GraphQL Server Schema

You can download the schema of a GraphQL server with:

```
:lua require("kulala").download_graphql_schema()
```

You need to have your cursor on a line with a GraphQL request.

The file will be downloaded to the the
directory where the current file is located.

The filename will be `[http-file-name-without-extension].graphql-schema.json`.

This file can be used in conjunction with
the [kulala-ls][kulala-ls] Language Server
to provide autocompletion and type checking.

[kulala-ls]: https://github.com/mistweaverco/kulala-ls
