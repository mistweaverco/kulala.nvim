local M = {}

---Busted-compatible stub: `stub(obj, "method", return_value)` with `:revert()`.
---@param obj table The object containing the method to stub.
---@param method string The name of the method to stub.
---@param returns any The value to return when the stubbed method is called.
function M.stub(obj, method, returns)
  local orig = obj[method]
  local stub_fn = function()
    return returns
  end

  stub_fn.revert = function()
    obj[method] = orig
  end

  obj[method] = stub_fn
  return stub_fn
end

return M
