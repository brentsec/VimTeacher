-- tests/test_insert_mode.lua
-- Tests for the insert mode lesson module

local insert = require("vimteacher.lessons.insert_mode")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_insert_mode: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(insert.title ~= nil, "Missing title")
assert_test(type(insert.description) == "table", "description must be table")
assert_test(type(insert.hint_lines) == "table", "hint_lines must be table")
assert_test(type(insert.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(insert.type == "insert", "type must be 'insert', got " .. tostring(insert.type))
assert_test(type(insert.allowed_keys) == "table", "allowed_keys must be table")
assert_test(#insert.allowed_keys > 0, "allowed_keys must not be empty")
assert_test(insert.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains only valid insert keys
local valid_insert_keys = { i = true, I = true, a = true, A = true, o = true, O = true }
for _, key in ipairs(insert.allowed_keys) do
	assert_test(valid_insert_keys[key], "Invalid allowed_key: " .. key)
end

-- Test 3: compute_optimal works (motion-aware, not Manhattan)
local opt = insert.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt == 2, "Different row+col should be 2, got " .. opt)

local opt2 = insert.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = insert.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt3 == 1, "Same col different row should be 1, got " .. opt3)

local opt4 = insert.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt4 == 1, "Same row different col should be 1, got " .. opt4)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_insert")
local challenge = insert.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(
	challenge.key == "i" or challenge.key == "a",
	"key must be 'i' or 'a', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: snippet_lines and expected_lines have same length
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

-- Test 8: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(target_char ~= " " and target_char ~= "\t", "Target must be on non-whitespace, got '" .. target_char .. "'")

-- Test 9: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
	local dist = math.abs(challenge.start_pos.row - challenge.target.row)
		+ math.abs(challenge.start_pos.col - challenge.target.col)
	assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 10: CRITICAL — Simulated edit correctness for ALL challenges
-- This verifies that applying key+char at target on snippet_lines produces expected_lines.
-- Would have caught the 5 wrong target column offsets.
local challenges = insert._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")
	assert_test(
		c.key == "i" or c.key == "a",
		"Challenge " .. idx .. ": key must be 'i' or 'a', got '" .. tostring(c.key) .. "'"
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

	-- Simulate the edit: insert char at target position
	local edited = vim.deepcopy(c.snippet_lines)
	local line = edited[c.target.row + 1]
	local col = c.target.col

	if c.key == "i" then
		-- i inserts BEFORE cursor position
		edited[c.target.row + 1] = line:sub(1, col) .. c.char .. line:sub(col + 1)
	else
		-- a appends AFTER cursor position
		edited[c.target.row + 1] = line:sub(1, col + 1) .. c.char .. line:sub(col + 2)
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
	local ch = insert.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_insert_mode")
