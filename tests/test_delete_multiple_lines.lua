-- tests/test_delete_multiple_lines.lua
-- Tests for the delete multiple lines lesson module (dj, dk, d2j, d2k)

local delete_multiple_lines = require("vimteacher.lessons.delete_multiple_lines")

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

print("test_delete_multiple_lines: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(delete_multiple_lines.title ~= nil, "Missing title")
assert_test(type(delete_multiple_lines.description) == "table", "description must be table")
assert_test(type(delete_multiple_lines.hint_lines) == "table", "hint_lines must be table")
assert_test(type(delete_multiple_lines.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(
	delete_multiple_lines.type == "insert",
	"type must be 'insert', got " .. tostring(delete_multiple_lines.type)
)
assert_test(type(delete_multiple_lines.allowed_keys) == "table", "allowed_keys must be table")
assert_test(delete_multiple_lines.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys is empty
assert_test(
	#delete_multiple_lines.allowed_keys == 0,
	"allowed_keys must be empty, got " .. #delete_multiple_lines.allowed_keys
)

-- Verify allowed_modify_keys contains only "d"
assert_test(type(delete_multiple_lines.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#delete_multiple_lines.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(delete_multiple_lines.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works (Manhattan distance)
local opt1 = delete_multiple_lines.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = delete_multiple_lines.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = delete_multiple_lines.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = delete_multiple_lines.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = delete_multiple_lines.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_delete_multiple_lines")
local challenge = delete_multiple_lines.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key == nil, "key should not be exposed in generated challenge")
assert_test(challenge.goal_text ~= nil, "Missing goal_text")
assert_test(type(challenge.highlight_rows) == "table", "Missing highlight_rows")
assert_test(#challenge.highlight_rows >= 2, "highlight_rows must have at least 2 rows")

-- Test 5: expected_lines has fewer lines than snippet_lines (multi-line deletion)
assert_test(
	#challenge.expected_lines < #challenge.snippet_lines,
	"expected_lines must have fewer lines than snippet_lines, got "
		.. #challenge.expected_lines
		.. " >= "
		.. #challenge.snippet_lines
)

-- Test 6: snippet_lines and expected_lines differ
local lines_differ = false
for i = 1, math.min(#challenge.snippet_lines, #challenge.expected_lines) do
	if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
		lines_differ = true
		break
	end
end
-- Since line counts differ, they must differ even if some lines are the same
assert_test(
	#challenge.expected_lines < #challenge.snippet_lines or lines_differ,
	"snippet_lines and expected_lines must differ"
)

-- Test 7: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
	challenge.target.row < #challenge.snippet_lines,
	"target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)
local target_line = challenge.snippet_lines[challenge.target.row + 1]
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(
	challenge.target.col < #target_line,
	"target.col out of bounds: " .. challenge.target.col .. " >= " .. #target_line
)

-- Test 8: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
	local dist = math.abs(challenge.start_pos.row - challenge.target.row)
		+ math.abs(challenge.start_pos.col - challenge.target.col)
	assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 9: CRITICAL — Simulated multi-line delete correctness for ALL challenges
-- dj: deletes target row and row below (2 lines)
-- dk: deletes target row and row above (2 lines)
-- d2j: deletes target row and 2 rows below (3 lines)
-- d2k: deletes target row and 2 rows above (3 lines)
local challenges = delete_multiple_lines._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(
		c.key == "dj" or c.key == "dk" or c.key == "d2j" or c.key == "d2k",
		"Challenge " .. idx .. ": key must be 'dj', 'dk', 'd2j', or 'd2k', got '" .. tostring(c.key) .. "'"
	)

	-- Verify expected_lines has fewer lines than snippet_lines
	local lines_removed = 0
	if c.key == "dj" or c.key == "dk" then
		lines_removed = 2
	elseif c.key == "d2j" or c.key == "d2k" then
		lines_removed = 3
	end

	assert_test(
		#c.expected_lines == #c.snippet_lines - lines_removed,
		"Challenge "
			.. idx
			.. ": expected_lines count "
			.. #c.expected_lines
			.. " must equal snippet_lines count - "
			.. lines_removed
			.. " ("
			.. (#c.snippet_lines - lines_removed)
			.. ")"
	)

	-- Verify target is within snippet bounds
	assert_test(
		c.target.row < #c.snippet_lines,
		"Challenge " .. idx .. ": target.row " .. c.target.row .. " >= " .. #c.snippet_lines
	)
	local sline = c.snippet_lines[c.target.row + 1]
	assert_test(
		c.target.col < #sline,
		"Challenge " .. idx .. ": target.col " .. c.target.col .. " >= " .. #sline .. " (line: '" .. sline .. "')"
	)

	-- Simulate the multi-line delete
	local edited = vim.deepcopy(c.snippet_lines)
	local target_row = c.target.row + 1 -- Convert to 1-indexed

	if c.key == "dj" then
		-- Delete target row and row below (2 lines)
		-- Verify there's a row below
		assert_test(
			target_row < #edited,
			"Challenge " .. idx .. ": dj requires row below target, but target is last row"
		)
		table.remove(edited, target_row + 1) -- Remove row below first
		table.remove(edited, target_row) -- Then remove target row
	elseif c.key == "dk" then
		-- Delete target row and row above (2 lines)
		-- Verify there's a row above
		assert_test(target_row > 1, "Challenge " .. idx .. ": dk requires row above target, but target is first row")
		table.remove(edited, target_row) -- Remove target row first
		table.remove(edited, target_row - 1) -- Then remove row above
	elseif c.key == "d2j" then
		-- Delete target row and 2 rows below (3 lines)
		-- Verify there are 2 rows below
		assert_test(target_row + 2 <= #edited, "Challenge " .. idx .. ": d2j requires 2 rows below target")
		table.remove(edited, target_row + 2) -- Remove bottom row first
		table.remove(edited, target_row + 1) -- Then middle row
		table.remove(edited, target_row) -- Then target row
	elseif c.key == "d2k" then
		-- Delete target row and 2 rows above (3 lines)
		-- Verify there are 2 rows above
		assert_test(target_row > 2, "Challenge " .. idx .. ": d2k requires 2 rows above target")
		table.remove(edited, target_row) -- Remove target row first
		table.remove(edited, target_row - 1) -- Then row above
		table.remove(edited, target_row - 2) -- Then row 2 above
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

-- Test 10: Run 50 generations without crashes
for i = 1, 50 do
	local ch = delete_multiple_lines.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
	assert_test(ch.goal_text ~= nil, "Generation " .. i .. " returned nil goal_text")
	assert_test(type(ch.highlight_rows) == "table", "Generation " .. i .. " missing highlight_rows")
	-- Verify line count difference
	assert_test(
		#ch.expected_lines < #ch.snippet_lines,
		"Generation " .. i .. ": expected_lines must have fewer lines than snippet_lines"
	)
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_delete_multiple_lines: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
