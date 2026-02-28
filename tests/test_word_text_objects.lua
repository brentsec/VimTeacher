-- tests/test_word_text_objects.lua
-- Tests for the word text objects lesson module (diw, daw, ciw, caw)

local word_text_objects = require("vimteacher.lessons.word_text_objects")

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

print("test_word_text_objects: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(word_text_objects.title ~= nil, "Missing title")
assert_test(type(word_text_objects.description) == "table", "description must be table")
assert_test(type(word_text_objects.hint_lines) == "table", "hint_lines must be table")
assert_test(type(word_text_objects.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(word_text_objects.type == "insert", "type must be 'insert', got " .. tostring(word_text_objects.type))
assert_test(type(word_text_objects.allowed_keys) == "table", "allowed_keys must be table")
assert_test(word_text_objects.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#word_text_objects.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #word_text_objects.allowed_keys
)
assert_test(word_text_objects.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains d
assert_test(type(word_text_objects.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#word_text_objects.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(word_text_objects.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works (Manhattan distance to reach target word)
local opt1 = word_text_objects.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = word_text_objects.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = word_text_objects.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = word_text_objects.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = word_text_objects.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_word_text_objects")
local challenge = word_text_objects.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")

-- For ciw/caw, char must be present
if challenge.key == "ciw" or challenge.key == "caw" then
	assert_test(challenge.char ~= nil, "Missing char for " .. challenge.key)
end

assert_test(
	challenge.key == "diw" or challenge.key == "daw" or challenge.key == "ciw" or challenge.key == "caw",
	"key must be 'diw', 'daw', 'ciw', or 'caw', got '" .. tostring(challenge.key) .. "'"
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

-- Test 8: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
	local dist = math.abs(challenge.start_pos.row - challenge.target.row)
		+ math.abs(challenge.start_pos.col - challenge.target.col)
	assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 9: CRITICAL — Simulated edit correctness for ALL challenges
local challenges = word_text_objects._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

-- Helper: find word boundaries around col (word = [%w_]+ chars)
local function find_word_bounds(line, col)
	-- Find start of word
	local word_start = col
	while word_start > 0 do
		local ch = line:sub(word_start, word_start)
		if not ch:match("[%w_]") then
			break
		end
		word_start = word_start - 1
	end
	if word_start > 0 or not line:sub(1, 1):match("[%w_]") then
		word_start = word_start + 1
	end

	-- Find end of word
	local word_end = col
	while word_end <= #line do
		local ch = line:sub(word_end, word_end)
		if not ch:match("[%w_]") then
			break
		end
		word_end = word_end + 1
	end
	word_end = word_end - 1

	return word_start, word_end
end

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(
		c.key == "diw" or c.key == "daw" or c.key == "ciw" or c.key == "caw",
		"Challenge " .. idx .. ": key must be 'diw', 'daw', 'ciw', or 'caw', got '" .. tostring(c.key) .. "'"
	)

	-- For ciw/caw, char must be present
	if c.key == "ciw" or c.key == "caw" then
		assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char for " .. c.key)
	end

	-- Verify same line count (word text objects don't add/remove lines)
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

	-- Find word boundaries (0-indexed, inclusive)
	local word_start, word_end = find_word_bounds(line, col + 1)
	word_start = word_start - 1 -- Convert to 0-indexed
	word_end = word_end - 1 -- Convert to 0-indexed

	if c.key == "diw" then
		-- Delete inner word only (preserve surrounding spaces)
		edited[c.target.row + 1] = line:sub(1, word_start) .. line:sub(word_end + 2)
	elseif c.key == "daw" then
		-- Delete a word (word + trailing space if exists)
		local delete_end = word_end + 1
		if delete_end < #line and line:sub(delete_end + 1, delete_end + 1) == " " then
			delete_end = delete_end + 1
		end
		edited[c.target.row + 1] = line:sub(1, word_start) .. line:sub(delete_end + 1)
	elseif c.key == "ciw" then
		-- Change inner word (delete word, insert replacement)
		edited[c.target.row + 1] = line:sub(1, word_start) .. c.char .. line:sub(word_end + 2)
	elseif c.key == "caw" then
		-- Change a word (delete word + space, insert replacement)
		local delete_end = word_end + 1
		if delete_end < #line and line:sub(delete_end + 1, delete_end + 1) == " " then
			delete_end = delete_end + 1
		end
		edited[c.target.row + 1] = line:sub(1, word_start) .. c.char .. line:sub(delete_end + 1)
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

-- Test 10: Run 50 generations without crashes
for i = 1, 50 do
	local ch = word_text_objects.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_word_text_objects: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
