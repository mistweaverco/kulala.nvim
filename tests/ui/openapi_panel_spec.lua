describe("openapi panel render", function()
  local Render = require("kulala.ui.openapi_panel.render")

  local sample_tree = {
    {
      id = "root",
      kind = "section",
      title = "API",
      badge = "1.0",
      children = {
        {
          id = "tag:pets",
          kind = "section",
          title = "pets",
          badge = "2",
          children = {
            {
              id = "op:GET /pets",
              kind = "operation",
              title = "GET /pets",
              operationKey = "GET /pets",
              children = {
                {
                  id = "section:GET /pets:tryItOut",
                  kind = "section",
                  title = "Try it out",
                  badge = "1",
                  children = {
                    {
                      id = "try:GET /pets:limit",
                      kind = "tryItOut",
                      title = "limit (query)",
                      operationKey = "GET /pets",
                      paramName = "limit",
                      defaultValue = "10",
                    },
                  },
                },
              },
            },
          },
        },
      },
    },
  }

  it("renders folded sections without children", function()
    local folds = { ["tag:pets"] = true }
    local lines, line_map = Render.build_lines(sample_tree, folds, {})
    assert.are.equal(2, #lines)
    assert.are.equal("v API [1.0]", lines[1])
    assert.are.equal("  > pets [2]", lines[2])
    assert.are.equal(2, #line_map)
  end)

  it("renders try it out values from state", function()
    local folds = { ["section:GET /pets:tryItOut"] = false }
    local try_values = { ["GET /pets"] = { limit = "25" } }
    local lines = Render.build_lines(sample_tree, folds, try_values)
    local try_line = vim.tbl_filter(function(l)
      return l:match("limit %(query%) = ")
    end, lines)[1]
    assert.is_truthy(try_line)
    assert.are.equal("        v limit (query) = 25", try_line)
  end)

  it("renders descriptions under nodes", function()
    local tree = {
      {
        id = "op:GET /x",
        kind = "operation",
        title = "GET /x",
        description = "Returns logo bytes",
        children = {},
      },
    }
    local lines = Render.build_lines(tree, {}, {})
    assert.is_truthy(vim.tbl_filter(function(l)
      return l:match("Returns logo bytes")
    end, lines)[1])
  end)
end)
