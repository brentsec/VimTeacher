-- tests/test_change_around_brackets.lua
-- Tests for the change around brackets lesson module (ca(, ca[, ca{)

local change_around_brackets = require("vimteacher.lessons.change_around_brackets")

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

print("test_change_around_brackets: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(change_around_brackets.title ~= nil, "Missing title")
assert_test(type(change_around_brackets.description) == "table", "description must be table")
assert_test(type(change_around_brackets.hint_lines) == "table", "hint_lines must be table")
assert_test(type(change_around_brackets.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(
	change_around_brackets.type == "insert",
	"type must be 'insert', got " .. tostring(change_around_brackets.type)
)
assert_test(type(change_around_brackets.allowed_keys) == "table", "allowed_keys must be table")
assert_test(change_around_brackets.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#change_around_brackets.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #change_around_brackets.allowed_keys
)
assert_test(change_around_brackets.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Test 3: compute_optimal works (Manhattan distance to target position)
local opt1 = change_around_brackets.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = change_around_brackets.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = change_around_brackets.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = change_around_brackets.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = change_around_brackets.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_change_around_brackets")
local challenge = change_around_brackets.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(
	challenge.key == "ca(" or challenge.key == "ca[" or challenge.key == "ca{",
	"key must be 'ca(', 'ca[', or 'ca{', got '" .. tostring(challenge.key) .. "'"
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
-- ca(, ca[, ca{ delete opening/closing brackets AND contents, insert char
local challenges = change_around_brackets._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

-- Helper function to find matching bracket
local function find_bracket_pair(line, col, open_char, close_char)
	-- col is 1-indexed position in the string
	-- Search backward for opening bracket (from current position backward)
	local open_pos = nil
	for i = col - 1, 1, -1 do
		local c = line:sub(i, i)
		if c == open_char then
			open_pos = i - 1 -- Convert to 0-indexed
			break
		end
	end

	-- Search forward for closing bracket (from current position forward)
	local close_pos = nil
	for i = col + 1, #line do
		local c = line:sub(i, i)
		if c == close_char then
			close_pos = i - 1 -- Convert to 0-indexed
			break
		end
	end

	return open_pos, close_pos
end

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")
	assert_test(
		c.key == "ca(" or c.key == "ca[" or c.key == "ca{",
		"Challenge " .. idx .. ": key must be 'ca(', 'ca[', or 'ca{', got '" .. tostring(c.key) .. "'"
	)

	-- Verify same line count (ca operations don't add/remove lines)
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

	-- Simulate the edit
	local edited = vim.deepcopy(c.snippet_lines)
	local line = edited[c.target.row + 1]
	local col = c.target.col

	-- Determine bracket type
	local open_char, close_char
	if c.key == "ca(" then
		open_char, close_char = "(", ")"
	elseif c.key == "ca[" then
		open_char, close_char = "[", "]"
	elseif c.key == "ca{" then
		open_char, close_char = "{", "}"
	end

	-- Find bracket positions (convert to 1-indexed for Lua string operations)
	local open_pos, close_pos = find_bracket_pair(line, col + 1, open_char, close_char)

	if open_pos and close_pos then
		-- Delete from open_pos to close_pos (inclusive), insert char
		edited[c.target.row + 1] = line:sub(1, open_pos) .. c.char .. line:sub(close_pos + 2)
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
	local ch = change_around_brackets.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_change_around_brackets: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
