# GraphQL

Use `GRAPHQL` method to indicate a GRAPHQL request.

`@graphql` directive or `X-REQUEST-TYPE: GraphQL` header may also work, but are deprecated and will not activate all the features of the GraphQL request.

Create a file with the `.http` extension and write your GraphQL requests in it.

## With variables

```http title="gql-with-variables.http"
GRAPHQL https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
Accept: application/json

query Person($id: ID) {
  person(personID: $id) {
    name
  }
}

{ "id": 1 }
```

## Without variables

```http title="gql-without-variables.http"
GRAPHQL https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
Accept: application/json

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

You need to have your cursor within then section with the GraphQL request.

The file will be downloaded to the the
directory where the current file is located.

The filename will be `"request_name"|"request_host".graphql-schema.json`.

## Autocompletion

For autocompletion and type checking to work, make sure:

1. Request method is `GRAPHQL`
3. GraphQL schema is downloaded

