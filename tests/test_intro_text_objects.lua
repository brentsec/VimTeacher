-- tests/test_intro_text_objects.lua
-- Tests for the intro to text objects lesson module

local intro = require("vimteacher.lessons.intro_text_objects")

local pass_count = 0
local fail_count = 0

local function assert_test(condition, msg)
  if condition then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
    print("  FAIL: " .. msg)
  end
end

print("test_intro_text_objects: running...")

-- Test 1: Module has all required fields
assert_test(intro.title ~= nil, "Missing title")
assert_test(type(intro.description) == "table", "description must be table")
assert_test(type(intro.hint_lines) == "table", "hint_lines must be table")
assert_test(type(intro.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Info-specific fields
assert_test(intro.type == "info", "type must be 'info', got " .. tostring(intro.type))
assert_test(type(intro.sandbox_snippet) == "table", "sandbox_snippet must be table")
assert_test(#intro.sandbox_snippet > 0, "sandbox_snippet must not be empty")

-- Test 3: All sandbox_snippet entries are strings
for i, line in ipairs(intro.sandbox_snippet) do
  assert_test(type(line) == "string", "sandbox_snippet[" .. i .. "] must be string, got " .. type(line))
end

-- Test 4: All description entries are strings
for i, line in ipairs(intro.description) do
  assert_test(type(line) == "string", "description[" .. i .. "] must be string, got " .. type(line))
end

-- Test 5: All hint_lines entries are strings
for i, line in ipairs(intro.hint_lines) do
  assert_test(type(line) == "string", "hint_lines[" .. i .. "] must be string, got " .. type(line))
end

-- Test 6: sandbox_snippet contains bracket and quote examples
local snippet_text = table.concat(intro.sandbox_snippet, " ")
assert_test(snippet_text:find("%(") ~= nil or snippet_text:find("%)") ~= nil, "sandbox_snippet should contain parentheses")
assert_test(snippet_text:find("%[") ~= nil or snippet_text:find("%]") ~= nil, "sandbox_snippet should contain brackets")
assert_test(snippet_text:find('"') ~= nil, "sandbox_snippet should contain quotes")

-- Test 7: Description mentions text objects, "inside", and "around"
local desc_text = table.concat(intro.description, " ")
assert_test(desc_text:find("text object") ~= nil or desc_text:find("Text object") ~= nil, "Description should mention 'text object'")
assert_test(desc_text:find("inside") ~= nil or desc_text:find("INSIDE") ~= nil, "Description should mention 'inside'")
assert_test(desc_text:find("around") ~= nil or desc_text:find("AROUND") ~= nil, "Description should mention 'around'")

-- Test 8: Hint lines mention relevant operations
local hint_text = table.concat(intro.hint_lines, " ")
assert_test(hint_text:find("di%(") ~= nil or hint_text:find("Delete inside") ~= nil, "Hints should mention di( or delete inside")
assert_test(hint_text:find("Enter") ~= nil, "Hints should mention Enter (next lesson)")

-- Test 9: generate_challenge returns valid structure
local challenge = intro.generate_challenge()
assert_test(type(challenge) == "table", "generate_challenge must return a table")
assert_test(challenge.snippet_lines ~= nil, "Challenge must have snippet_lines")
assert_test(type(challenge.snippet_lines) == "table", "snippet_lines must be a table")
assert_test(#challenge.snippet_lines > 0, "snippet_lines must not be empty")

-- Test 10: generate_challenge returns a deep copy (not the same reference)
local challenge2 = intro.generate_challenge()
assert_test(challenge.snippet_lines ~= challenge2.snippet_lines, "Each call should return a deep copy")
assert_test(challenge.snippet_lines ~= intro.sandbox_snippet, "snippet_lines should not be same reference as sandbox_snippet")

-- Test 11: Should NOT have challenge-based fields
assert_test(intro.challenges_required == nil, "Info lesson should not have challenges_required")
assert_test(intro.compute_optimal == nil, "Info lesson should not have compute_optimal")

-- Test 12: sandbox_modify_keys contains text-object-relevant keys
assert_test(type(intro.sandbox_modify_keys) == "table", "sandbox_modify_keys must be table")
local smk_set = {}
for _, key in ipairs(intro.sandbox_modify_keys) do smk_set[key] = true end
assert_test(smk_set["d"] == true, "sandbox_modify_keys must contain 'd'")
assert_test(smk_set["c"] == true, "sandbox_modify_keys must contain 'c'")
assert_test(smk_set["y"] == true, "sandbox_modify_keys must contain 'y'")
assert_test(smk_set["u"] == true, "sandbox_modify_keys must contain 'u'")

-- Summary
print(string.format("test_intro_text_objects: %d passed, %d failed (total: %d assertions)",
  pass_count, fail_count, pass_count + fail_count))

if fail_count > 0 then
  os.exit(1)
end
