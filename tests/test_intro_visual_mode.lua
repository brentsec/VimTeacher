-- tests/test_intro_visual_mode.lua
-- Tests for the intro to visual mode lesson module

local intro = require("vimteacher.lessons.intro_visual_mode")

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

print("test_intro_visual_mode: running...")

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

-- Test 6: Description mentions key visual mode concepts
local desc_text = table.concat(intro.description, " ")
assert_test(
	desc_text:find("visual mode") ~= nil or desc_text:find("Visual mode") ~= nil,
	"Description should mention 'visual mode'"
)
assert_test(desc_text:find("v") ~= nil, "Description should mention 'v' key")
assert_test(desc_text:find("Esc") ~= nil, "Description should mention 'Esc'")

-- Test 7: Hint lines mention key bindings
local hint_text = table.concat(intro.hint_lines, " ")
assert_test(hint_text:find("visual") ~= nil or hint_text:find("Visual") ~= nil, "Hints should mention visual mode")
assert_test(hint_text:find("Esc") ~= nil, "Hints should mention Esc")
assert_test(hint_text:find("Enter") ~= nil, "Hints should mention Enter (next lesson)")

-- Test 8: generate_challenge returns valid structure
local challenge = intro.generate_challenge()
assert_test(type(challenge) == "table", "generate_challenge must return a table")
assert_test(challenge.snippet_lines ~= nil, "Challenge must have snippet_lines")
assert_test(type(challenge.snippet_lines) == "table", "snippet_lines must be a table")
assert_test(#challenge.snippet_lines > 0, "snippet_lines must not be empty")

-- Test 9: generate_challenge returns a deep copy (not the same reference)
local challenge2 = intro.generate_challenge()
assert_test(challenge.snippet_lines ~= challenge2.snippet_lines, "Each call should return a deep copy")
assert_test(
	challenge.snippet_lines ~= intro.sandbox_snippet,
	"snippet_lines should not be same reference as sandbox_snippet"
)

-- Test 10: Should NOT have challenge-based fields
assert_test(intro.challenges_required == nil, "Info lesson should not have challenges_required")
assert_test(intro.compute_optimal == nil, "Info lesson should not have compute_optimal")
assert_test(intro.allowed_keys == nil, "Info lesson should not have allowed_keys")

-- Summary
print(
	string.format(
		"test_intro_visual_mode: %d passed, %d failed (total: %d assertions)",
		pass_count,
		fail_count,
		pass_count + fail_count
	)
)

if fail_count > 0 then
	os.exit(1)
end
