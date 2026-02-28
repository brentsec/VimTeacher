-- tests/test_window_scrolls.lua
-- Tests for the window scrolls lesson module

local window_scrolls = require("vimteacher.lessons.window_scrolls")

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

print("test_window_scrolls: running...")

-- Test 1: Module has all required fields
assert_test(window_scrolls.title ~= nil, "Missing title")
assert_test(type(window_scrolls.description) == "table", "description must be table")
assert_test(type(window_scrolls.hint_lines) == "table", "hint_lines must be table")
assert_test(type(window_scrolls.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Info-specific fields
assert_test(window_scrolls.type == "info", "type must be 'info', got " .. tostring(window_scrolls.type))
assert_test(type(window_scrolls.sandbox_snippet) == "table", "sandbox_snippet must be table")
assert_test(
	#window_scrolls.sandbox_snippet >= 10,
	"sandbox_snippet must have 10+ lines for scrolling, got " .. #window_scrolls.sandbox_snippet
)

-- Test 3: All sandbox_snippet entries are strings
for i, line in ipairs(window_scrolls.sandbox_snippet) do
	assert_test(type(line) == "string", "sandbox_snippet[" .. i .. "] must be string, got " .. type(line))
end

-- Test 4: All description entries are strings
for i, line in ipairs(window_scrolls.description) do
	assert_test(type(line) == "string", "description[" .. i .. "] must be string, got " .. type(line))
end

-- Test 5: All hint_lines entries are strings
for i, line in ipairs(window_scrolls.hint_lines) do
	assert_test(type(line) == "string", "hint_lines[" .. i .. "] must be string, got " .. type(line))
end

-- Test 6: Description mentions scrolling concepts
local desc_text = table.concat(window_scrolls.description, " ")
assert_test(
	desc_text:lower():find("ctrl+d") ~= nil or desc_text:lower():find("ctrl%+d") ~= nil,
	"Description should mention 'Ctrl+d'"
)
assert_test(
	desc_text:lower():find("ctrl+u") ~= nil or desc_text:lower():find("ctrl%+u") ~= nil,
	"Description should mention 'Ctrl+u'"
)

-- Test 7: Hint lines mention key bindings
local hint_text = table.concat(window_scrolls.hint_lines, " ")
assert_test(hint_text:find("Ctrl") ~= nil, "Hints should mention Ctrl key")
assert_test(hint_text:find("%[n%]") ~= nil, "Hints should mention [n] (next lesson)")

-- Test 8: generate_challenge returns valid structure
local challenge = window_scrolls.generate_challenge()
assert_test(type(challenge) == "table", "generate_challenge must return a table")
assert_test(challenge.snippet_lines ~= nil, "Challenge must have snippet_lines")
assert_test(type(challenge.snippet_lines) == "table", "snippet_lines must be a table")
assert_test(#challenge.snippet_lines > 0, "snippet_lines must not be empty")

-- Test 9: generate_challenge returns a deep copy (not the same reference)
local challenge2 = window_scrolls.generate_challenge()
assert_test(challenge.snippet_lines ~= challenge2.snippet_lines, "Each call should return a deep copy")
assert_test(
	challenge.snippet_lines ~= window_scrolls.sandbox_snippet,
	"snippet_lines should not be same reference as sandbox_snippet"
)

-- Test 10: Should NOT have challenge-based fields
assert_test(window_scrolls.challenges_required == nil, "Info lesson should not have challenges_required")
assert_test(window_scrolls.compute_optimal == nil, "Info lesson should not have compute_optimal")
assert_test(window_scrolls.allowed_keys == nil, "Info lesson should not have allowed_keys")

-- Summary
print(
	string.format(
		"test_window_scrolls: %d passed, %d failed (total: %d assertions)",
		pass_count,
		fail_count,
		pass_count + fail_count
	)
)

if fail_count > 0 then
	os.exit(1)
end
