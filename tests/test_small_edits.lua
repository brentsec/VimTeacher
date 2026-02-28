-- tests/test_small_edits.lua
-- Tests for the small edits lesson module (cl, x, r)

local small_edits = require("vimteacher.lessons.small_edits")

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

print("test_small_edits: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(small_edits.title ~= nil, "Missing title")
assert_test(type(small_edits.description) == "table", "description must be table")
assert_test(type(small_edits.hint_lines) == "table", "hint_lines must be table")
assert_test(type(small_edits.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(small_edits.type == "insert", "type must be 'insert', got " .. tostring(small_edits.type))
assert_test(type(small_edits.allowed_keys) == "table", "allowed_keys must be table")
assert_test(small_edits.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(#small_edits.allowed_keys == 1, "allowed_keys must have 1 entry, got " .. #small_edits.allowed_keys)
assert_test(small_edits.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains x and r
assert_test(type(small_edits.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#small_edits.allowed_modify_keys == 2, "allowed_modify_keys must have 2 entries")
local modify_set = {}
for _, key in ipairs(small_edits.allowed_modify_keys) do
	modify_set[key] = true
end
assert_test(modify_set["x"] == true, "allowed_modify_keys must contain 'x'")
assert_test(modify_set["r"] == true, "allowed_modify_keys must contain 'r'")

-- Verify allowed_nav_keys contains exactly h,j,k,l,w,b,e
assert_test(type(small_edits.allowed_nav_keys) == "table", "allowed_nav_keys must be table")
local nav_set = {}
for _, key in ipairs(small_edits.allowed_nav_keys) do
	nav_set[key] = true
end
assert_test(#small_edits.allowed_nav_keys == 7, "allowed_nav_keys must have 7 entries")
for _, key in ipairs({ "h", "j", "k", "l", "w", "b", "e" }) do
	assert_test(nav_set[key] == true, "allowed_nav_keys must contain '" .. key .. "'")
end

-- Test 3: semantic optimal is computed across all lesson challenges
local challenges = small_edits._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)
local strictly_better_than_manhattan = false
for idx, c in ipairs(challenges) do
	local opt = small_edits._compute_nav_optimal(c.snippet_lines, c.start_pos, c.target)
	local manhattan = math.abs(c.start_pos.row - c.target.row) + math.abs(c.start_pos.col - c.target.col)
	assert_test(opt >= 0, "Challenge " .. idx .. ": optimal must be >= 0, got " .. opt)
	assert_test(
		opt <= manhattan,
		"Challenge " .. idx .. ": semantic optimal should not exceed Manhattan (" .. opt .. " > " .. manhattan .. ")"
	)
	if opt < manhattan then
		strictly_better_than_manhattan = true
	end
end
assert_test(
	strictly_better_than_manhattan,
	"Expected at least one challenge where semantic optimal is better than Manhattan"
)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_small_edits")
local challenge = small_edits.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(
	challenge.key == "x" or challenge.key == "r" or challenge.key == "cl",
	"key must be 'x', 'r', or 'cl', got '" .. tostring(challenge.key) .. "'"
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
-- x: deletes char at target col
-- r: replaces char at target col with c.char (single char)
-- s: deletes char at target col, inserts c.char (multi-char)
for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")
	assert_test(
		c.key == "x" or c.key == "r" or c.key == "cl",
		"Challenge " .. idx .. ": key must be 'x', 'r', or 'cl', got '" .. tostring(c.key) .. "'"
	)

	-- Verify same line count (s/x/r don't add/remove lines)
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

	if c.key == "x" then
		-- x deletes char at target col
		edited[c.target.row + 1] = line:sub(1, col) .. line:sub(col + 2)
	elseif c.key == "r" or c.key == "cl" then
		-- r replaces char at target col with c.char; cl deletes char then inserts c.char
		edited[c.target.row + 1] = line:sub(1, col) .. c.char .. line:sub(col + 2)
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
	local ch = small_edits.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_small_edits: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
