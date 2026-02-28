-- tests/test_change_words.lua
-- Tests for the change_words lesson module (cw, cW)

local change_words = require("vimteacher.lessons.change_words")

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

print("test_change_words: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(change_words.title ~= nil, "Missing title")
assert_test(type(change_words.description) == "table", "description must be table")
assert_test(type(change_words.hint_lines) == "table", "hint_lines must be table")
assert_test(type(change_words.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(change_words.type == "insert", "type must be 'insert', got " .. tostring(change_words.type))
assert_test(type(change_words.allowed_keys) == "table", "allowed_keys must be table")
assert_test(change_words.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(#change_words.allowed_keys == 1, "allowed_keys must have 1 entry, got " .. #change_words.allowed_keys)
assert_test(change_words.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys is empty (change enters insert mode, no normal modify keys)
assert_test(type(change_words.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#change_words.allowed_modify_keys == 0, "allowed_modify_keys must be empty for change operator")

-- Test 3: compute_optimal works (navigation + 1 for operation)
local opt1 = change_words.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 3, "Different row and col should be 2 moves + 1 = 3, got " .. opt1)

local opt2 = change_words.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 1, "Same position should be 0 moves + 1 = 1, got " .. opt2)

local opt3 = change_words.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 2, "Same row, different col should be 1 move + 1 = 2, got " .. opt3)

local opt4 = change_words.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 2, "Different row, same col should be 1 move + 1 = 2, got " .. opt4)

local opt5 = change_words.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 3, "Different row and col should be 2 moves + 1 = 3, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_change_words")
local challenge = change_words.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(
	challenge.key == "cw" or challenge.key == "cW",
	"key must be 'cw' or 'cW', got '" .. tostring(challenge.key) .. "'"
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

-- Test 9: Start position has distance >= 1 from target
if challenge.start_pos then
	local row_same = (challenge.start_pos.row == challenge.target.row)
	local col_same = (challenge.start_pos.col == challenge.target.col)
	local dist = 0
	if not row_same then
		dist = dist + 1
	end
	if not col_same then
		dist = dist + 1
	end
	assert_test(dist >= 1, "Start must be different from target, got dist " .. dist)
end

-- Test 10: CRITICAL — Simulated edit correctness for ALL challenges
-- cw: deletes from cursor to next word boundary, inserts char
-- cW: deletes from cursor to next WORD boundary (space), inserts char
local challenges = change_words._get_challenges()
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
		c.key == "cw" or c.key == "cW",
		"Challenge " .. idx .. ": key must be 'cw' or 'cW', got '" .. tostring(c.key) .. "'"
	)

	-- Verify same line count (cw/cW don't add/remove lines)
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

	local before = line:sub(1, col)
	local rest = line:sub(col + 1)
	local word_end

	if c.key == "cw" then
		-- cw: delete to next word boundary (non-word char)
		word_end = rest:find("[^%w_]") or (#rest + 1)
	elseif c.key == "cW" then
		-- cW: delete to next WORD boundary (space)
		word_end = rest:find(" ") or (#rest + 1)
	end

	local after = rest:sub(word_end)
	edited[c.target.row + 1] = before .. c.char .. after

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
	local ch = change_words.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_change_words: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
