## Usage

`examples.http`

```http

# Make a request to the PokeAPI to get information about ditto
# Use HTTP/1.0 and the application/json content type as headers
GET https://pokeapi.co/api/v2/pokemon/ditto HTTP/1.0
accept: application/json

###

# Make a request to the Star Wars API to get information about all films
# Use a GraphQL query to get the title and episodeID of each film
# Use the application/json content type as the header and omit the HTTP version
# so it defaults to HTTP/1.1
GET https://swapi-graphql.netlify.app/.netlify/functions/index
accept: application/json

< ./starwars.graphql

###

POST https://swapi-graphql.netlify.app/.netlify/functions/index
accept: application/json
content-type: application/json

{
  "query": "{ allFilms { films { title } } }",
  "variables": {}
}

###
```

`starwars.graphql`

```graphql
query {
  allFilms {
    films {
      title
      episodeID
    }
  }
}
```

Place the cursor on any item
in the `examples.http` and
run `:lua require('kulala').run()`.

