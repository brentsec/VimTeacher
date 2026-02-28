-- tests/test_relative_line_jumps.lua
-- Tests for the relative line jumps lesson module

local relative = require("vimteacher.lessons.relative_line_jumps")

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

print("test_relative_line_jumps: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(relative.title ~= nil, "Missing title")
assert_test(type(relative.description) == "table", "description must be table")
assert_test(type(relative.hint_lines) == "table", "hint_lines must be table")
assert_test(type(relative.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: compute_optimal works
-- Same position = 0
local opt0 = relative.compute_optimal({ row = 5, col = 10 }, { row = 5, col = 10 })
assert_test(opt0 == 0, "Same position should be 0 distance, got " .. opt0)

-- Same row, different col = 1 (horizontal move)
local opt1 = relative.compute_optimal({ row = 5, col = 10 }, { row = 5, col = 15 })
assert_test(opt1 == 1, "Same row, different col should be 1 move, got " .. opt1)

-- Different row, same col = 1 (counted jump like 5j)
local opt2 = relative.compute_optimal({ row = 2, col = 10 }, { row = 7, col = 10 })
assert_test(opt2 == 1, "Different row, same col should be 1 move (counted jump), got " .. opt2)

-- Different row AND col = 2 (jump + horizontal)
local opt3 = relative.compute_optimal({ row = 2, col = 5 }, { row = 8, col = 12 })
assert_test(opt3 == 2, "Different row and col should be 2 moves, got " .. opt3)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_relative")
local challenge = relative.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.goal_text ~= nil, "Missing goal_text")

-- Test 4: Target is within snippet bounds
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

-- Test 5: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(target_char ~= " " and target_char ~= "\t", "Target must be on non-whitespace, got '" .. target_char .. "'")

-- Test 6: Start position has at least 3 rows vertical distance from target
if challenge.start_pos then
	local row_dist = math.abs(challenge.start_pos.row - challenge.target.row)
	assert_test(row_dist >= 3, "Start must be >= 3 rows from target, got " .. row_dist)
end

-- Test 7: Snippet has at least 8 lines (requirement for this lesson)
assert_test(#challenge.snippet_lines >= 8, "Snippet must have >= 8 lines, got " .. #challenge.snippet_lines)

-- Test 8: Run 50 generations without crashes
for i = 1, 50 do
	local ch = relative.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.goal_text ~= nil, "Generation " .. i .. " missing goal_text")
	assert_test(#ch.snippet_lines >= 8, "Generation " .. i .. " has < 8 lines: " .. #ch.snippet_lines)

	-- Verify target is always on non-whitespace
	local tl = ch.snippet_lines[ch.target.row + 1]
	if tl then
		local tc = tl:sub(ch.target.col + 1, ch.target.col + 1)
		assert_test(
			tc ~= " " and tc ~= "\t" and tc ~= "",
			"Generation " .. i .. ": target on whitespace/empty at (" .. ch.target.row .. "," .. ch.target.col .. ")"
		)
	end

	-- Verify vertical distance requirement
	if ch.start_pos then
		local rd = math.abs(ch.start_pos.row - ch.target.row)
		assert_test(rd >= 3, "Generation " .. i .. ": start only " .. rd .. " rows from target")
	end
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_relative_line_jumps: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
