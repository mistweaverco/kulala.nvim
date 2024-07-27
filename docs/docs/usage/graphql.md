# GraphQL

You can use the `@graphql` directive to send GraphQL requests.

Create a file with the `.http` extension and write your GraphQL requests in it.

## With variables

```http title="gql-with-variables.http"
POST https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
accept: application/json
# @graphql 1

query Person($id: ID) {
  person(personID: $id) {
    name
  }
}
variables { "id": 1 }
```

## Without variables

```http title="gql-without-variables.http"
POST https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
accept: application/json
# @graphql 1

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
