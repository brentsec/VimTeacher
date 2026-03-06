-- tests/test_paragraph_jumps.lua
-- Tests for the paragraph jumps lesson module

local para = require("vimteacher.lessons.paragraph_jumps")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_paragraph_jumps: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(para.title ~= nil, "Missing title")
assert_test(type(para.description) == "table", "description must be table")
assert_test(type(para.hint_lines) == "table", "hint_lines must be table")
assert_test(type(para.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(para.dwell_time) == "number", "dwell_time must be number")

-- Test 2: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_para")
local challenge = para.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.goal_text ~= nil, "Missing goal_text")
assert_test(challenge.highlight_rows ~= nil, "Missing highlight_rows")

-- Test 3: Target is on a blank line at col 0
local target_line = challenge.snippet_lines[challenge.target.row + 1]
assert_test(target_line == "", "Target must be on a blank line, got '" .. tostring(target_line) .. "'")
assert_test(challenge.target.col == 0, "Target col must be 0 for blank line, got " .. challenge.target.col)

-- Test 4: highlight_rows matches target row
assert_test(#challenge.highlight_rows == 1, "highlight_rows should have 1 entry, got " .. #challenge.highlight_rows)
assert_test(challenge.highlight_rows[1] == challenge.target.row, "highlight_rows[1] should match target.row")

-- Test 5: Start position is on a non-blank line, at least 3 rows from target
local start_line = challenge.snippet_lines[challenge.start_pos.row + 1]
assert_test(start_line ~= "", "Start must be on a non-blank line")
local row_dist = math.abs(challenge.start_pos.row - challenge.target.row)
assert_test(row_dist >= 3, "Start must be >= 3 rows from target, got " .. row_dist)

-- Test 6: compute_optimal after generate (blank lines are populated)
-- Same position should be 0
local opt = para.compute_optimal(challenge.target, challenge.target)
assert_test(opt == 0, "Same position should be 0, got " .. opt)

-- From start to target should be >= 1 (at least one paragraph jump)
local opt2 = para.compute_optimal(challenge.start_pos, challenge.target)
assert_test(opt2 >= 1, "Start to target should need >= 1 jump, got " .. opt2)

-- Test 7: Snippet has at least one blank line
local has_blank = false
for _, line in ipairs(challenge.snippet_lines) do
	if line == "" then
		has_blank = true
		break
	end
end
assert_test(has_blank, "Snippet must have at least one blank line for paragraph boundaries")

-- Test 8: Run 50 generations without crashes
for i = 1, 50 do
	local ch = para.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.goal_text ~= nil, "Generation " .. i .. " missing goal_text")
	assert_test(ch.highlight_rows ~= nil, "Generation " .. i .. " missing highlight_rows")

	-- Verify target is always on a blank line at col 0
	local tl = ch.snippet_lines[ch.target.row + 1]
	assert_test(
		tl == "",
		"Generation "
			.. i
			.. ": target must be on blank line at row "
			.. ch.target.row
			.. ", got '"
			.. tostring(tl)
			.. "'"
	)
	assert_test(ch.target.col == 0, "Generation " .. i .. ": target.col must be 0, got " .. ch.target.col)

	-- Verify highlight_rows matches target
	assert_test(ch.highlight_rows[1] == ch.target.row, "Generation " .. i .. ": highlight_rows must match target row")

	-- Verify start is on non-blank line
	local sl = ch.snippet_lines[ch.start_pos.row + 1]
	assert_test(sl ~= "", "Generation " .. i .. ": start must be on non-blank line")

	-- Verify compute_optimal returns reasonable value
	local o = para.compute_optimal(ch.start_pos, ch.target)
	assert_test(o >= 1, "Generation " .. i .. ": optimal must be >= 1, got " .. o)
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_paragraph_jumps")
