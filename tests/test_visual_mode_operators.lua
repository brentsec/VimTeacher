-- tests/test_visual_mode_operators.lua
-- Tests for the visual mode operators lesson module (v + d, v + c)

local visual_mode_operators = require("vimteacher.lessons.visual_mode_operators")

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

print("test_visual_mode_operators: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(visual_mode_operators.title ~= nil, "Missing title")
assert_test(type(visual_mode_operators.description) == "table", "description must be table")
assert_test(type(visual_mode_operators.hint_lines) == "table", "hint_lines must be table")
assert_test(type(visual_mode_operators.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(
	visual_mode_operators.type == "insert",
	"type must be 'insert', got " .. tostring(visual_mode_operators.type)
)
assert_test(type(visual_mode_operators.allowed_keys) == "table", "allowed_keys must be table")
assert_test(visual_mode_operators.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#visual_mode_operators.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #visual_mode_operators.allowed_keys
)
assert_test(visual_mode_operators.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains d
assert_test(type(visual_mode_operators.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#visual_mode_operators.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(visual_mode_operators.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Verify allowed_visual_keys contains v
assert_test(type(visual_mode_operators.allowed_visual_keys) == "table", "allowed_visual_keys must be table")
assert_test(#visual_mode_operators.allowed_visual_keys == 1, "allowed_visual_keys must have 1 entry")
assert_test(visual_mode_operators.allowed_visual_keys[1] == "v", "allowed_visual_keys[1] must be 'v'")

-- Test 3: compute_optimal works (Manhattan distance to target)
local opt1 = visual_mode_operators.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = visual_mode_operators.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = visual_mode_operators.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = visual_mode_operators.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = visual_mode_operators.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_visual_mode_operators")
local challenge = visual_mode_operators.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(challenge.select_end ~= nil, "Missing select_end")
assert_test(challenge.select_end.row ~= nil, "Missing select_end.row")
assert_test(challenge.select_end.col ~= nil, "Missing select_end.col")
assert_test(
	challenge.key == "vd" or challenge.key == "vc",
	"key must be 'vd' or 'vc', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: snippet_lines and expected_lines have same length (no line additions)
assert_test(
	#challenge.snippet_lines == #challenge.expected_lines,
	"snippet_lines and expected_lines must have same length"
)

-- Test 6: snippet_lines and expected_lines differ (there's something to fix)
local lines_differ = false
for i = 1, #challenge.snippet_lines do
	if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
		lines_differ = true
		break
	end
end
assert_test(lines_differ, "snippet_lines and expected_lines must differ")

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

-- Test 8: select_end is on same row and >= target.col (single-line visual selection)
assert_test(
	challenge.select_end.row == challenge.target.row,
	"select_end.row must equal target.row for single-line selection"
)
assert_test(challenge.select_end.col >= challenge.target.col, "select_end.col must be >= target.col")

-- Test 9: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
	local dist = math.abs(challenge.start_pos.row - challenge.target.row)
		+ math.abs(challenge.start_pos.col - challenge.target.col)
	assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 10: CRITICAL — Simulated edit correctness for ALL challenges
-- vd: deletes characters from target.col to select_end.col (inclusive)
-- vc: deletes same range, then inserts c.char
local challenges = visual_mode_operators._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")
	assert_test(c.select_end ~= nil, "Challenge " .. idx .. ": missing select_end")
	assert_test(
		c.key == "vd" or c.key == "vc",
		"Challenge " .. idx .. ": key must be 'vd' or 'vc', got '" .. tostring(c.key) .. "'"
	)

	-- Verify same line count (vd/vc don't add/remove lines)
	assert_test(
		#c.expected_lines == #c.snippet_lines,
		"Challenge "
			.. idx
			.. ": expected_lines count "
			.. #c.expected_lines
			.. " must equal snippet_lines count "
			.. #c.snippet_lines
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

	-- Verify select_end is on same row and >= target.col
	assert_test(
		c.select_end.row == c.target.row,
		"Challenge " .. idx .. ": select_end.row must equal target.row for single-line selection"
	)
	assert_test(
		c.select_end.col >= c.target.col,
		"Challenge " .. idx .. ": select_end.col " .. c.select_end.col .. " must be >= target.col " .. c.target.col
	)
	assert_test(
		c.select_end.col < #sline,
		"Challenge " .. idx .. ": select_end.col " .. c.select_end.col .. " >= " .. #sline
	)

	-- Simulate the edit
	local edited = vim.deepcopy(c.snippet_lines)
	local line = edited[c.target.row + 1]
	local start_col = c.target.col
	local end_col = c.select_end.col

	if c.key == "vd" then
		-- vd deletes characters from start_col to end_col (inclusive)
		edited[c.target.row + 1] = line:sub(1, start_col) .. line:sub(end_col + 2)
	elseif c.key == "vc" then
		-- vc deletes same range, then inserts c.char
		edited[c.target.row + 1] = line:sub(1, start_col) .. c.char .. line:sub(end_col + 2)
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
				.. edited[i]
				.. "' expected '"
				.. c.expected_lines[i]
				.. "'"
		)
	end
end

-- Test 11: Run 50 generations without crashes
for i = 1, 50 do
	local ch = visual_mode_operators.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
	assert_test(ch.select_end ~= nil, "Generation " .. i .. " returned nil select_end")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_visual_mode_operators: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
