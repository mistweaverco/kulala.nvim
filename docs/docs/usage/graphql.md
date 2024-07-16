# GraphQL

Create a file with the `.http` extension and write your GraphQL requests in it.

## With variables

```http title="gql-with-variables.http"

# @graphql 1
POST https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
accept: application/json

query Person($id: ID) {
  person(personID: $id) {
    name
  }
}
variables { "id": 1 }

```

## Without variables

```http title="gql-without-variables.http"

# @graphql 1
POST https://swapi-graphql.netlify.app/.netlify/functions/index HTTP/1.1
accept: application/json

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
