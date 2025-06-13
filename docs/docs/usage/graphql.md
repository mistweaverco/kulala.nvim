# GraphQL

You can use the `GRAPHQL` method (preferred), `@graphql` directive or `X-REQUEST-TYPE: GraphQL` header to send GraphQL requests.

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
default keymap `<leader>Rg` or the relevant code action.

You need to have your cursor on a line within the GraphQL request.

This is required for the autocompletion and type checking to work.

The file will be downloaded to the the
directory where the current file is located.

The filename will be `"request_name"|"request_host".graphql-schema.json`.
