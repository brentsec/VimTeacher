-- tests/test_find_char.lua
-- Tests for the find character lesson module (f, F, ;)

local find_char = require("vimteacher.lessons.find_char")

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

print("test_find_char: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(find_char.title ~= nil, "Missing title")
assert_test(type(find_char.description) == "table", "description must be table")
assert_test(type(find_char.hint_lines) == "table", "hint_lines must be table")
assert_test(type(find_char.generate_challenge) == "function", "generate_challenge must be function")
assert_test(find_char.dwell_time ~= nil, "Missing dwell_time")

-- Test 2: compute_optimal
local opt1 = find_char.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 0 })
assert_test(opt1 == 0, "Same position should be 0, got " .. opt1)

local opt2 = find_char.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 10 })
assert_test(opt2 == 1, "Same row different col should be 1, got " .. opt2)

local opt3 = find_char.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 2 })
assert_test(opt3 == 2, "Different row should be 2, got " .. opt3)

local opt4 = find_char.compute_optimal({ row = 2, col = 15 }, { row = 2, col = 3 })
assert_test(opt4 == 1, "Same row backward should be 1, got " .. opt4)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_find_char")
local challenge = find_char.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

-- Test 4: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
	challenge.target.row < #challenge.snippet_lines,
	"target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)
local tline = challenge.snippet_lines[challenge.target.row + 1]
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(challenge.target.col < #tline, "target.col out of bounds: " .. challenge.target.col .. " >= " .. #tline)

-- Test 5: Target is on non-whitespace
local target_char = tline:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(target_char ~= " " and target_char ~= "\t", "Target must be on non-whitespace, got '" .. target_char .. "'")

-- Test 6: Start and target are on the same line (for f/F)
assert_test(
	challenge.start_pos.row == challenge.target.row,
	"Start and target should be on same line: start row "
		.. challenge.start_pos.row
		.. " != target row "
		.. challenge.target.row
)

-- Test 7: Start and target are at different columns
assert_test(challenge.start_pos.col ~= challenge.target.col, "Start and target must have different columns")

-- Test 8: Run 50 generations without crashes + verify same-line constraint
for i = 1, 50 do
	local ch = find_char.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")

	-- Verify same line
	assert_test(
		ch.start_pos.row == ch.target.row,
		"Generation " .. i .. ": start row " .. ch.start_pos.row .. " != target row " .. ch.target.row
	)

	-- Verify target is on non-whitespace
	local gen_line = ch.snippet_lines[ch.target.row + 1]
	local gen_char = gen_line:sub(ch.target.col + 1, ch.target.col + 1)
	assert_test(
		gen_char ~= " " and gen_char ~= "\t",
		"Generation " .. i .. ": target on whitespace '" .. gen_char .. "'"
	)

	-- Verify different columns
	assert_test(ch.start_pos.col ~= ch.target.col, "Generation " .. i .. ": start col == target col")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_find_char: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
