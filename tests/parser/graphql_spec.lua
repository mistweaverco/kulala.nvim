local Graphql = require("kulala.parser.graphql")

describe("graphql parser", function()
  it("parses query and variables sections", function()
    local body = table.concat({
      "query Person($id: ID) {",
      "  person(personID: $id) { name }",
      "}",
      "{",
      '  "id": 1',
      "}",
    }, "\n")

    local _, json = Graphql.get_json(body)
    assert.are.same("query Person($id: ID) { person(personID: $id) { name } }", json.query)
    assert.are.same({ id = 1 }, json.variables)
  end)
end)
