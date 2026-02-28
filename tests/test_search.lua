-- tests/test_search.lua
-- Tests for the search lesson module

local search = require("vimteacher.lessons.search")

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

print("test_search: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(search.title ~= nil, "Missing title")
assert_test(type(search.description) == "table", "description must be table")
assert_test(type(search.hint_lines) == "table", "hint_lines must be table")
assert_test(type(search.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: compute_optimal works (search is always 2 actions: / + n)
local opt = search.compute_optimal({ row = 0, col = 0 }, { row = 10, col = 20 })
assert_test(opt == 2, "Search to different position should be 2, got " .. opt)

local opt2 = search.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_search")
local challenge = search.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.search_word ~= nil, "Missing search_word")
assert_test(type(challenge.search_word) == "string", "search_word must be string")
assert_test(#challenge.search_word >= 2, "search_word must be at least 2 chars, got " .. #challenge.search_word)
assert_test(challenge.target_end_col ~= nil, "Missing target_end_col")
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

-- Test 5: Target is on the search_word
local target_substr = target_line:sub(challenge.target.col + 1, challenge.target.col + #challenge.search_word)
assert_test(
	target_substr == challenge.search_word,
	"Target must be on search_word '" .. challenge.search_word .. "', got '" .. target_substr .. "'"
)

-- Test 6: Start position is at least 3 rows from target
if challenge.start_pos then
	local row_dist = math.abs(challenge.start_pos.row - challenge.target.row)
	assert_test(row_dist >= 3, "Start must be >= 3 rows from target, got " .. row_dist)
end

-- Test 7: Run 50 generations without crashes
for i = 1, 50 do
	local ch = search.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.search_word ~= nil, "Generation " .. i .. " missing search_word")
	assert_test(ch.target_end_col ~= nil, "Generation " .. i .. " missing target_end_col")
	assert_test(ch.goal_text ~= nil, "Generation " .. i .. " missing goal_text")

	-- Verify target is always on non-whitespace
	local tl = ch.snippet_lines[ch.target.row + 1]
	if tl then
		local tc = tl:sub(ch.target.col + 1, ch.target.col + 1)
		assert_test(
			tc ~= " " and tc ~= "\t" and tc ~= "",
			"Generation " .. i .. ": target on whitespace/empty at (" .. ch.target.row .. "," .. ch.target.col .. ")"
		)
	end

	-- Verify start is at least 3 rows away
	if ch.start_pos then
		local rd = math.abs(ch.start_pos.row - ch.target.row)
		assert_test(rd >= 3, "Generation " .. i .. ": start too close (" .. rd .. " rows)")
	end
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_search: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
