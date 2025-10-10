# Code Review: feat(parser): shared block

## Commit Information
- **Commit Hash**: cccaa8097b99d4bd9456b4d810022514c4c9552e
- **Author**: Yaro <yaro@dream-it.es>
- **Date**: Sat Oct 4 22:28:04 2025 +0300
- **Message**: feat(parser): shared block

## Overview
This commit introduces the "Shared Block" feature to the kulala.nvim HTTP client. This is an initial commit that adds the entire repository structure, with the shared block being the primary new feature.

## Feature Summary
The Shared Block feature allows users to define reusable components (variables, metadata, scripts, and requests) that can be shared across multiple HTTP requests in a document. Two variants are supported:
1. `### Shared` - Scripts and requests execute once before all requests
2. `### Shared each` - Scripts and requests execute before each individual request

## Files Changed
The commit adds the entire repository structure, with key parser files:
- `lua/kulala/parser/document.lua` (669 lines) - Main document parsing logic
- `lua/kulala/parser/request.lua` (662 lines) - Request processing logic
- Documentation: `docs/docs/usage/shared-blocks.md`
- Tests: `tests/functional/parser_spec.lua`, `tests/functional/requests_spec.lua`

## Detailed Analysis

### 1. Implementation Quality ✅ GOOD

#### Strengths:
1. **Clean Separation of Concerns**: The implementation cleanly separates shared block parsing from request processing
2. **Type Safety**: Proper Lua annotations are used (`---@class DocumentRequest`)
3. **Consistent Naming**: Uses clear naming conventions (`Shared` vs `Shared each`)
4. **Test Coverage**: Comprehensive tests cover both parser behavior and runtime execution

#### Code Quality Examples:
```lua
-- Good: Clear distinction between shared block types
if request.name == "Shared" or request.name == "Shared each" then
  shared = request
  shared.url = #shared.url > 0 and shared.url or nil
```

### 2. Design Decisions 🤔 REVIEW NEEDED

#### Potential Issues:

##### Issue #1: Missing Script Inheritance ⚠️
**Location**: `lua/kulala/parser/document.lua:550-567`

The `apply_shared_data` function only applies metadata and variables from shared blocks, but **NOT scripts**:

```lua
local function apply_shared_data(shared, request)
  -- Only applies metadata and variables
  vim.iter(shared.metadata):each(function(metadata)
    if not vim.tbl_contains(request_metadata, metadata.name) then 
      table.insert(request.metadata, metadata) 
    end
  end)

  vim.iter(shared.variables):each(function(k, v)
    if not request.variables[k] then request.variables[k] = v end
  end)

  return request
  -- NOTE: Scripts are NOT applied here!
end
```

**Expected Behavior** (from documentation):
> "Scripts and requests declared in the shared block and called with `run` command will be executed before the request you run."

**Actual Behavior**: Scripts from shared blocks are executed through the `expand_nested_requests` function which adds the shared block as a separate request to be executed, not by copying scripts to the target request.

**Assessment**: This is actually **correct by design**. The shared block is treated as a complete request that gets executed separately. This prevents script duplication and maintains execution order.

##### Issue #2: Case Sensitivity 🔍
**Location**: Multiple locations

The code uses exact string matching for "Shared" and "Shared each":

```lua
if request.name == "Shared" or request.name == "Shared each" then
  -- ...
end

if not requests[1].name:match("Shared") and is_runnable(shared) then
  if shared.name == "Shared each" then
```

**Concern**: Mixed matching approach:
- Line 517: Uses exact equality (`==`)
- Line 580: Uses pattern matching (`match("Shared")`)

**Risk**: Potential inconsistency. For example, `"Shared each extra text"` would:
- NOT match the exact equality check on line 517
- WOULD match the pattern check on line 580

**Recommendation**: Use consistent matching throughout. Consider using exact matching everywhere:
```lua
if shared.name == "Shared" or shared.name == "Shared each" then
```

##### Issue #3: Empty Shared Block Handling ✅
**Location**: `lua/kulala/parser/request.lua:629`

```lua
local empty_request = false
if not request.url then empty_request = true end -- shared blocks with no URL
```

**Assessment**: Good defensive coding. Shared blocks without URLs are properly handled and don't cause execution errors.

### 3. Variable Scoping Logic ✅ EXCELLENT

The implementation properly handles two variable scoping modes:

```lua
-- In document.lua line 198:
if Config.options.variables_scope == "document" then 
  request.shared.variables[variable_name] = variable_value 
end
```

This allows for:
1. **Document scope**: Variables cascade and can be overridden
2. **Request scope**: Each request's variables are isolated

The tests confirm this works correctly.

### 4. Metadata Merging ✅ GOOD

**Location**: `lua/kulala/parser/document.lua:558-560`

```lua
vim.iter(shared.metadata):each(function(metadata)
  if not vim.tbl_contains(request_metadata, metadata.name) then 
    table.insert(request.metadata, metadata) 
  end
end)
```

**Assessment**: Correct implementation. Request-level metadata takes precedence over shared metadata (no overwrite if exists).

### 5. Execution Flow ✅ WELL DESIGNED

The `expand_nested_requests` function properly implements the different execution patterns:

```lua
if shared.name == "Shared each" then
  -- Insert shared block before EACH request
  vim.iter(requests_):each(function(request)
    table.insert(requests, shared)
    table.insert(requests, request)
  end)
else
  -- Insert shared block ONCE at the beginning
  table.insert(requests, 1, shared)
end
```

This correctly implements:
- `### Shared`: Run once before all requests
- `### Shared each`: Run before each request

### 6. Edge Cases 🧪

#### Handled Well:
1. ✅ Shared blocks without URLs
2. ✅ Empty shared blocks
3. ✅ Multiple requests with shared data
4. ✅ Nested requests within shared blocks
5. ✅ Variable scope switching

#### Potential Edge Cases to Consider:
1. 🤔 Multiple shared blocks in one file - Only the first one is used (line 578: `local shared = requests[1].shared`)
2. 🤔 Shared block as the only content (no other requests)
3. 🤔 Shared block appearing after regular requests

### 7. Documentation ✅ COMPREHENSIVE

The documentation clearly explains:
- Purpose and use cases
- Syntax for both variants
- Variable scoping behavior
- Execution order

**Example from docs**:
```http
### Shared
@shared_var_1 = shared_value_1
# @curl-connect-timeout 20
run ./login.http
```

### 8. Test Coverage ✅ EXCELLENT

Tests cover:
- Parser behavior (extracting shared data)
- Variable merging with different scopes
- Metadata merging
- Script execution order
- "Shared" vs "Shared each" behavior
- Empty shared blocks
- Nested requests

Example test:
```lua
it("runs all requests with shared block - once", function()
  kulala.run_all()
  wait_for_requests(3)
  assert.is_same(3, curl.requests_no)
  -- Verifies shared block runs once
end)
```

## Recommendations

### High Priority:
1. ✅ **FIXED: Consistency in Shared Name Matching**: Changed pattern matching to exact equality checks to avoid edge cases with naming like "Shared extra"

### Medium Priority:
2. **Document Multiple Shared Blocks Behavior**: Clarify in documentation what happens when multiple shared blocks exist (currently only first is used)
3. **Add Edge Case Tests**: Test scenarios like:
   - Multiple shared blocks in one file
   - Shared block appearing after regular requests
   - Shared block as sole content

### Low Priority:
4. **Consider Case-Insensitive Matching**: Make shared block detection case-insensitive for better UX (`shared`, `SHARED`, `Shared` all work)

## Suggested Code Improvements

### 1. ✅ FIXED: Pattern Matching Inconsistency

**File**: `lua/kulala/parser/document.lua:580`

**Previous**:
```lua
if not requests[1].name:match("Shared") and is_runnable(shared) then
  if shared.name == "Shared each" then
```

**Fixed to**:
```lua
if not (requests[1].name == "Shared" or requests[1].name == "Shared each") and is_runnable(shared) then
  if shared.name == "Shared each" then
```

**Rationale**: Prevents false positives with names like "Shared test" or "SharedX"

**Test Added**: Added test case in `tests/functional/parser_spec.lua` to verify that request names containing "Shared" but not being actual shared blocks are handled correctly.

### 2. Add Early Return for Invalid Shared Names

**File**: `lua/kulala/parser/document.lua:517-519`

**Current**:
```lua
if request.name == "Shared" or request.name == "Shared each" then
  shared = request
  shared.url = #shared.url > 0 and shared.url or nil
```

**Suggested**:
```lua
local valid_shared_names = { "Shared", "Shared each" }
if vim.tbl_contains(valid_shared_names, request.name) then
  shared = request
  shared.url = #shared.url > 0 and shared.url or nil
```

**Rationale**: Makes it easier to maintain valid shared block names in one place

## Security Considerations ✅
No security issues identified:
- No user input directly executed
- Scripts are handled through established script execution paths
- File paths are properly normalized

## Performance Considerations ✅
The implementation is efficient:
- Shared data applied once, not repeatedly
- Proper use of iterators
- Minimal deep copying (only where necessary)

## Breaking Changes ⚠️
Since this is an initial commit, no breaking changes. However, this establishes patterns that should be maintained:
- Exact naming convention for shared blocks
- Variable scoping behavior
- Execution order guarantees

## Overall Assessment ⭐⭐⭐⭐⭐ (5/5 stars)

**Strengths**:
- Well-designed feature with clear use cases
- Comprehensive test coverage
- Good documentation
- Clean implementation
- **Pattern matching inconsistency fixed**

**Improvements Made**:
- ✅ Fixed pattern matching to use exact equality checks
- ✅ Added test case for edge case with similar request names
- ✅ Enhanced documentation with important notes about naming

## Conclusion

This is a **solid implementation** of a useful feature. The code is well-structured, tested, and documented. The minor pattern matching inconsistency has been identified and fixed to prevent edge cases with request names that contain "Shared" but are not actual shared blocks.

**Final Recommendation**: ✅ **APPROVED - Issues Fixed**

## Changes Made in This Review

1. **Fixed Pattern Matching Bug** (`lua/kulala/parser/document.lua:580`)
   - Changed from `requests[1].name:match("Shared")` to exact equality check
   - Prevents false positives with names like "Shared test request"

2. **Added Test Coverage** (`tests/functional/parser_spec.lua`)
   - Added test case for requests with "Shared" in name but not being shared blocks
   - Verifies that shared variables still apply correctly

3. **Enhanced Documentation** (`docs/docs/usage/shared-blocks.md`)
   - Added "Important Notes" section
   - Clarified exact naming requirements
   - Documented behavior with multiple shared blocks
   - Added best practices
