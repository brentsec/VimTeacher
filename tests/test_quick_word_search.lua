-- tests/test_quick_word_search.lua
-- Tests for the quick word search lesson module

local quick_word_search = require("vimteacher.lessons.quick_word_search")

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

print("test_quick_word_search: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(quick_word_search.title ~= nil, "Missing title")
assert_test(type(quick_word_search.description) == "table", "description must be table")
assert_test(type(quick_word_search.hint_lines) == "table", "hint_lines must be table")
assert_test(type(quick_word_search.dwell_time) == "number", "dwell_time must be number")
assert_test(type(quick_word_search.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(quick_word_search.compute_optimal) == "function", "compute_optimal must be function")

-- Test 2: compute_optimal works
local opt = quick_word_search.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 0 })
assert_test(opt == 0, "Same position should be 0, got " .. opt)

local opt2 = quick_word_search.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt2 == 2, "Different position should be 2 (* + n/N), got " .. opt2)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_quick_word_search")
local challenge = quick_word_search.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.target_end_col ~= nil, "Missing target_end_col")
assert_test(challenge.search_word ~= nil, "Missing search_word")
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

-- Test 6: Start position is within bounds and on non-whitespace
assert_test(challenge.start_pos.row >= 0, "start_pos.row must be >= 0")
assert_test(
	challenge.start_pos.row < #challenge.snippet_lines,
	"start_pos.row out of bounds: " .. challenge.start_pos.row
)
local start_line = challenge.snippet_lines[challenge.start_pos.row + 1]
assert_test(challenge.start_pos.col >= 0, "start_pos.col must be >= 0")
assert_test(challenge.start_pos.col < #start_line, "start_pos.col out of bounds: " .. challenge.start_pos.col)
local start_char = start_line:sub(challenge.start_pos.col + 1, challenge.start_pos.col + 1)
assert_test(
	start_char ~= " " and start_char ~= "\t",
	"Start position must be on non-whitespace, got '" .. start_char .. "'"
)

-- Test 7: Start position is at least 3 rows away from target
local row_dist = math.abs(challenge.start_pos.row - challenge.target.row)
assert_test(row_dist >= 3, "Start must be >= 3 rows from target, got " .. row_dist)

-- Test 8: Run 50 generations without crashes
for i = 1, 50 do
	local ch = quick_word_search.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
	assert_test(ch.target_end_col ~= nil, "Generation " .. i .. " missing target_end_col")
	assert_test(ch.search_word ~= nil, "Generation " .. i .. " missing search_word")
	assert_test(ch.goal_text ~= nil, "Generation " .. i .. " missing goal_text")

	-- Verify target is on non-whitespace
	local tl = ch.snippet_lines[ch.target.row + 1]
	if tl then
		local tc = tl:sub(ch.target.col + 1, ch.target.col + 1)
		assert_test(
			tc ~= " " and tc ~= "\t" and tc ~= "",
			"Generation " .. i .. ": target on whitespace/empty at (" .. ch.target.row .. "," .. ch.target.col .. ")"
		)
	end

	-- Verify start is on non-whitespace
	local sl = ch.snippet_lines[ch.start_pos.row + 1]
	if sl then
		local sc = sl:sub(ch.start_pos.col + 1, ch.start_pos.col + 1)
		assert_test(
			sc ~= " " and sc ~= "\t" and sc ~= "",
			"Generation "
				.. i
				.. ": start on whitespace/empty at ("
				.. ch.start_pos.row
				.. ","
				.. ch.start_pos.col
				.. ")"
		)
	end

	-- Verify row distance >= 3
	local rd = math.abs(ch.start_pos.row - ch.target.row)
	assert_test(rd >= 3, "Generation " .. i .. ": row distance " .. rd .. " < 3")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_quick_word_search: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
