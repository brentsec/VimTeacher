-- tests/test_delete_lines.lua
-- Tests for the delete lines lesson module (dd, D)

local delete_lines = require("vimteacher.lessons.delete_lines")

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

print("test_delete_lines: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(delete_lines.title ~= nil, "Missing title")
assert_test(type(delete_lines.description) == "table", "description must be table")
assert_test(type(delete_lines.hint_lines) == "table", "hint_lines must be table")
assert_test(type(delete_lines.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(delete_lines.type == "insert", "type must be 'insert', got " .. tostring(delete_lines.type))
assert_test(type(delete_lines.allowed_keys) == "table", "allowed_keys must be table")
assert_test(delete_lines.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys is empty
assert_test(#delete_lines.allowed_keys == 0, "allowed_keys must be empty, got " .. #delete_lines.allowed_keys)

-- Verify allowed_modify_keys contains d, dd, D
assert_test(type(delete_lines.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(
	#delete_lines.allowed_modify_keys == 3,
	"allowed_modify_keys must have 3 entries, got " .. #delete_lines.allowed_modify_keys
)
local modify_set = {}
for _, key in ipairs(delete_lines.allowed_modify_keys) do
	modify_set[key] = true
end
assert_test(modify_set["d"] == true, "allowed_modify_keys must contain 'd'")
assert_test(modify_set["dd"] == true, "allowed_modify_keys must contain 'dd'")
assert_test(modify_set["D"] == true, "allowed_modify_keys must contain 'D'")

-- Test 3: compute_optimal works
-- For dd: navigate to correct row (col doesn't matter), then 1 operation
-- For D: navigate to exact (row, col), then 1 operation
local opt1 = delete_lines.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 3, "Row 0,Col 0 to Row 3,Col 5 should be 3, got " .. opt1)

local opt2 = delete_lines.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 1, "Same position should be 1 (just the operation), got " .. opt2)

local opt3 = delete_lines.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 2, "Same row, col 0 to 10 should be 2 (col move + op), got " .. opt3)

local opt4 = delete_lines.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 2, "Row 0 to 3, same col should be 2 (row move + op), got " .. opt4)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_delete_lines")
local challenge = delete_lines.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(
	challenge.key == "dd" or challenge.key == "D",
	"key must be 'dd' or 'D', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: For dd, expected_lines has 1 fewer line; for D, same count
if challenge.key == "dd" then
	assert_test(#challenge.expected_lines == #challenge.snippet_lines - 1, "dd: expected_lines must have 1 fewer line")
elseif challenge.key == "D" then
	assert_test(#challenge.expected_lines == #challenge.snippet_lines, "D: expected_lines must have same line count")
end

-- Test 6: snippet_lines and expected_lines differ
local lines_differ = false
for i = 1, math.min(#challenge.snippet_lines, #challenge.expected_lines) do
	if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
		lines_differ = true
		break
	end
end
if #challenge.snippet_lines ~= #challenge.expected_lines then
	lines_differ = true
end
assert_test(lines_differ, "snippet_lines and expected_lines must differ")

-- Test 7: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
	challenge.target.row < #challenge.snippet_lines,
	"target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)

-- Test 8: CRITICAL — Simulated edit correctness for ALL challenges
local challenges = delete_lines._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(
		c.key == "dd" or c.key == "D",
		"Challenge " .. idx .. ": key must be 'dd' or 'D', got '" .. tostring(c.key) .. "'"
	)

	-- Verify target is within snippet bounds
	assert_test(
		c.target.row < #c.snippet_lines,
		"Challenge " .. idx .. ": target.row " .. c.target.row .. " >= " .. #c.snippet_lines
	)

	-- Simulate the edit
	local edited = vim.deepcopy(c.snippet_lines)

	if c.key == "dd" then
		-- dd: remove entire line at target.row
		table.remove(edited, c.target.row + 1)

		-- Verify line count
		assert_test(#edited == #c.snippet_lines - 1, "Challenge " .. idx .. ": dd should remove 1 line")
		assert_test(
			#c.expected_lines == #c.snippet_lines - 1,
			"Challenge " .. idx .. ": dd expected_lines should have 1 fewer line"
		)
	elseif c.key == "D" then
		-- D: truncate line at target.col
		local line = edited[c.target.row + 1]
		edited[c.target.row + 1] = line:sub(1, c.target.col)

		-- Verify line count (same as before)
		assert_test(#edited == #c.snippet_lines, "Challenge " .. idx .. ": D should keep same line count")
		assert_test(
			#c.expected_lines == #c.snippet_lines,
			"Challenge " .. idx .. ": D expected_lines should have same line count"
		)
	end

	-- Compare edited snippet to expected_lines
	assert_test(
		#edited == #c.expected_lines,
		"Challenge " .. idx .. ": edited line count " .. #edited .. " != expected " .. #c.expected_lines
	)
	for i = 1, #c.expected_lines do
		assert_test(
			edited[i] == c.expected_lines[i],
			"Challenge "
				.. idx
				.. " line "
				.. i
				.. ": got '"
				.. tostring(edited[i])
				.. "' expected '"
				.. tostring(c.expected_lines[i])
				.. "'"
		)
	end
end

-- Test 9: Run 50 generations without crashes
for i = 1, 50 do
	local ch = delete_lines.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
	assert_test(ch.key == "dd" or ch.key == "D", "Generation " .. i .. " invalid key")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_delete_lines: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
