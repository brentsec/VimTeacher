-- tests/test_till_char.lua
-- Tests for the till character lesson module (t, T, ;)

local till_char = require("vimteacher.lessons.till_char")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_till_char: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(till_char.title ~= nil, "Missing title")
assert_test(type(till_char.description) == "table", "description must be table")
assert_test(type(till_char.hint_lines) == "table", "hint_lines must be table")
assert_test(type(till_char.generate_challenge) == "function", "generate_challenge must be function")
assert_test(till_char.dwell_time ~= nil, "Missing dwell_time")

-- Test 2: compute_optimal
local opt1 = till_char.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 0 })
assert_test(opt1 == 0, "Same position should be 0, got " .. opt1)

local opt2 = till_char.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 10 })
assert_test(opt2 == 1, "Same row different col should be 1, got " .. opt2)

local opt3 = till_char.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 2 })
assert_test(opt3 == 2, "Different row should be 2, got " .. opt3)

local opt4 = till_char.compute_optimal({ row = 2, col = 15 }, { row = 2, col = 3 })
assert_test(opt4 == 1, "Same row backward should be 1, got " .. opt4)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_till_char")
local challenge = till_char.generate_challenge(buf, ns)

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

-- Test 6: Target has an adjacent non-whitespace char (the search char for t/T)
local has_adjacent = false
if challenge.target.col > 0 then
	local prev = tline:sub(challenge.target.col, challenge.target.col)
	if prev ~= " " and prev ~= "\t" then
		has_adjacent = true
	end
end
if challenge.target.col < #tline - 1 then
	local nxt = tline:sub(challenge.target.col + 2, challenge.target.col + 2)
	if nxt ~= " " and nxt ~= "\t" then
		has_adjacent = true
	end
end
assert_test(has_adjacent, "Target must have adjacent non-whitespace char (search char for t/T)")

-- Test 7: Start and target are at different positions
assert_test(
	challenge.start_pos.row ~= challenge.target.row or challenge.start_pos.col ~= challenge.target.col,
	"Start and target must be different positions"
)

-- Test 8: Run 50 generations without crashes + verify all targets are valid
for i = 1, 50 do
	local ch = till_char.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")

	-- Verify target is on non-whitespace
	local gen_line = ch.snippet_lines[ch.target.row + 1]
	local gen_char = gen_line:sub(ch.target.col + 1, ch.target.col + 1)
	assert_test(
		gen_char ~= " " and gen_char ~= "\t",
		"Generation " .. i .. ": target on whitespace '" .. gen_char .. "'"
	)

	-- Verify target is within bounds
	assert_test(
		ch.target.col < #gen_line,
		"Generation " .. i .. ": target col " .. ch.target.col .. " >= line len " .. #gen_line
	)

	-- Verify start != target
	assert_test(
		ch.start_pos.row ~= ch.target.row or ch.start_pos.col ~= ch.target.col,
		"Generation " .. i .. ": start == target"
	)
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_till_char")
