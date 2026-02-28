-- tests/test_upper_word_movement.lua
-- Tests for the upper WORD movement lesson module (W, E, B)

local upper = require("vimteacher.lessons.upper_word_movement")

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

print("test_upper_word_movement: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(upper.title ~= nil, "Missing title")
assert_test(type(upper.description) == "table", "description must be table")
assert_test(type(upper.hint_lines) == "table", "hint_lines must be table")
assert_test(type(upper.generate_challenge) == "function", "generate_challenge must be function")
assert_test(upper.dwell_time ~= nil, "Missing dwell_time")

-- Test 2: _find_WORD_starts on simple strings
-- "hello world" -> 2 WORD starts at (0,0) and (0,6)
local ws1 = upper._find_WORD_starts({ "hello world" })
assert_test(#ws1 == 2, "Expected 2 WORD starts in 'hello world', got " .. #ws1)
assert_test(
	ws1[1].row == 0 and ws1[1].col == 0,
	"First WORD start should be (0,0), got (" .. ws1[1].row .. "," .. ws1[1].col .. ")"
)
assert_test(
	ws1[2].row == 0 and ws1[2].col == 6,
	"Second WORD start should be (0,6), got (" .. ws1[2].row .. "," .. ws1[2].col .. ")"
)

-- Test 3: _find_WORD_starts with symbols — NO boundaries!
-- "foo.bar" -> 1 WORD start (0,0) — symbols don't break WORDs
local ws2 = upper._find_WORD_starts({ "foo.bar" })
assert_test(#ws2 == 1, "Expected 1 WORD start in 'foo.bar', got " .. #ws2)
assert_test(ws2[1].col == 0, "foo.bar WORD starts at col 0, got " .. ws2[1].col)

-- Test 4: _find_WORD_starts with "foo.bar baz"
-- 2 WORDs: "foo.bar" at col 0, "baz" at col 8
local ws3 = upper._find_WORD_starts({ "foo.bar baz" })
assert_test(#ws3 == 2, "Expected 2 WORD starts in 'foo.bar baz', got " .. #ws3)
assert_test(ws3[1].col == 0, "foo.bar at col 0, got " .. ws3[1].col)
assert_test(ws3[2].col == 8, "baz at col 8, got " .. ws3[2].col)

-- Test 5: _find_WORD_starts with "a + b"
-- 3 WORDs: "a" at col 0, "+" at col 2, "b" at col 4
local ws4 = upper._find_WORD_starts({ "a + b" })
assert_test(#ws4 == 3, "Expected 3 WORD starts in 'a + b', got " .. #ws4)
assert_test(ws4[1].col == 0, "a at col 0, got " .. ws4[1].col)
assert_test(ws4[2].col == 2, "+ at col 2, got " .. ws4[2].col)
assert_test(ws4[3].col == 4, "b at col 4, got " .. ws4[3].col)

-- Test 6: _find_WORD_starts with leading whitespace
-- "  indented" -> 1 WORD start at (0,2)
local ws5 = upper._find_WORD_starts({ "  indented" })
assert_test(#ws5 == 1, "Expected 1 WORD start in '  indented', got " .. #ws5)
assert_test(ws5[1].col == 2, "indented at col 2, got " .. ws5[1].col)

-- Test 7: _find_WORD_starts multiline
local ws6 = upper._find_WORD_starts({ "foo bar", "baz" })
assert_test(#ws6 == 3, "Expected 3 WORD starts across 2 lines, got " .. #ws6)
assert_test(
	ws6[3].row == 1 and ws6[3].col == 0,
	"baz should be at (1,0), got (" .. ws6[3].row .. "," .. ws6[3].col .. ")"
)

-- Test 8: _find_WORD_starts with empty line
local ws7 = upper._find_WORD_starts({ "foo", "", "bar" })
assert_test(#ws7 == 2, "Expected 2 WORD starts (empty line skipped), got " .. #ws7)

-- Test 9: _find_WORD_starts complex — WORDs vs words comparison
-- "user.getName() = result;" -> 3 WORDs (word_movement would see many more)
local ws8 = upper._find_WORD_starts({ "user.getName() = result;" })
assert_test(#ws8 == 3, "Expected 3 WORD starts in 'user.getName() = result;', got " .. #ws8)
assert_test(ws8[1].col == 0, "user.getName() at col 0, got " .. ws8[1].col)
assert_test(ws8[2].col == 15, "= at col 15, got " .. ws8[2].col)
assert_test(ws8[3].col == 17, "result; at col 17, got " .. ws8[3].col)

-- Test 10: _find_WORD_starts with "arr[idx] += 1"
-- 3 WORDs: "arr[idx]" at col 0, "+=" at col 9, "1" at col 12
local ws9 = upper._find_WORD_starts({ "arr[idx] += 1" })
assert_test(#ws9 == 3, "Expected 3 WORD starts in 'arr[idx] += 1', got " .. #ws9)
assert_test(ws9[1].col == 0, "arr[idx] at col 0, got " .. ws9[1].col)
assert_test(ws9[2].col == 9, "+= at col 9, got " .. ws9[2].col)
assert_test(ws9[3].col == 12, "1 at col 12, got " .. ws9[3].col)

-- Test 11: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_upper_word")
local challenge = upper.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

-- Test 12: compute_optimal works
local opt = upper.compute_optimal(challenge.start_pos, challenge.target)
assert_test(opt >= 1, "Optimal moves should be >= 1, got " .. opt)

-- Test 13: Target is at a WORD start position
local all_ws = upper._find_WORD_starts(challenge.snippet_lines)
local target_is_word_start = false
for _, ws in ipairs(all_ws) do
	if ws.row == challenge.target.row and ws.col == challenge.target.col then
		target_is_word_start = true
		break
	end
end
assert_test(
	target_is_word_start,
	"Target (" .. challenge.target.row .. "," .. challenge.target.col .. ") must be a WORD start"
)

-- Test 14: Start position is at a WORD start position
local start_is_word_start = false
for _, ws in ipairs(all_ws) do
	if ws.row == challenge.start_pos.row and ws.col == challenge.start_pos.col then
		start_is_word_start = true
		break
	end
end
assert_test(
	start_is_word_start,
	"Start (" .. challenge.start_pos.row .. "," .. challenge.start_pos.col .. ") must be a WORD start"
)

-- Test 15: Run 50 generations without crashes
for i = 1, 50 do
	local ch = upper.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")

	-- Verify target is always at a WORD start
	local gen_ws = upper._find_WORD_starts(ch.snippet_lines)
	local found = false
	for _, ws in ipairs(gen_ws) do
		if ws.row == ch.target.row and ws.col == ch.target.col then
			found = true
			break
		end
	end
	assert_test(
		found,
		"Generation " .. i .. ": target (" .. ch.target.row .. "," .. ch.target.col .. ") not a WORD start"
	)
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_upper_word_movement: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
