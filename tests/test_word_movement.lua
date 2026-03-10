-- tests/test_word_movement.lua
-- Tests for the word movement lesson module

local word = require("vimteacher.lessons.word_movement")
local optimal = require("vimteacher.optimal")
local text_class = require("vimteacher.text_class")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_word_movement: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: shared char classification matches Vim-style word semantics
assert_test(text_class.char_class(nil) == "space", "nil should classify as space")
assert_test(text_class.char_class("") == "space", "empty string should classify as space")
assert_test(text_class.char_class(" ") == "space", "space should classify as space")
assert_test(text_class.char_class("\t") == "space", "tab should classify as space")
assert_test(text_class.char_class("a") == "word", "letters should classify as word")
assert_test(text_class.char_class("7") == "word", "digits should classify as word")
assert_test(text_class.char_class("_") == "word", "underscore should classify as word")
assert_test(text_class.char_class(".") == "punct", "punctuation should classify as punct")

-- Test 2: Module has all required fields
assert_test(word.title ~= nil, "Missing title")
assert_test(type(word.description) == "table", "description must be table")
assert_test(type(word.hint_lines) == "table", "hint_lines must be table")
assert_test(type(word.generate_challenge) == "function", "generate_challenge must be function")

-- Test 3: optimal tokenization respects the same word/punct boundaries
local nav_lines = { "foo.bar baz" }
local dot_target = optimal.nav_cost(nav_lines, { row = 0, col = 0 }, { row = 0, col = 3 }, { "w" })
local bar_target = optimal.nav_cost(nav_lines, { row = 0, col = 0 }, { row = 0, col = 4 }, { "w" })
local baz_target = optimal.nav_cost(nav_lines, { row = 0, col = 0 }, { row = 0, col = 8 }, { "w" })
assert_test(dot_target == 1, "w should reach punctuation token in one hop, got " .. dot_target)
assert_test(bar_target == 2, "w should reach the next word after punctuation in two hops, got " .. bar_target)
assert_test(baz_target == 3, "w should reach the following word after punctuation in three hops, got " .. baz_target)

-- Test 4: find_word_starts on known strings
local ws1 = word._find_word_starts({ "hello world" })
-- "hello" starts at col 0, "world" starts at col 6
assert_test(#ws1 == 2, "Expected 2 word starts in 'hello world', got " .. #ws1)
assert_test(
	ws1[1].row == 0 and ws1[1].col == 0,
	"First word start should be (0,0), got (" .. ws1[1].row .. "," .. ws1[1].col .. ")"
)
assert_test(
	ws1[2].row == 0 and ws1[2].col == 6,
	"Second word start should be (0,6), got (" .. ws1[2].row .. "," .. ws1[2].col .. ")"
)

-- Test 5: find_word_starts with punctuation class transitions
-- "foo.bar" -> foo(0), .(3), bar(4) — three words in Vim
local ws2 = word._find_word_starts({ "foo.bar" })
assert_test(#ws2 == 3, "Expected 3 word starts in 'foo.bar', got " .. #ws2)
assert_test(ws2[1].col == 0, "foo starts at col 0, got " .. ws2[1].col)
assert_test(ws2[2].col == 3, ". starts at col 3, got " .. ws2[2].col)
assert_test(ws2[3].col == 4, "bar starts at col 4, got " .. ws2[3].col)

-- Test 6: find_word_starts with mixed content
-- "x = 42" -> x(0), =(2), 42(4) — three words
local ws3 = word._find_word_starts({ "x = 42" })
assert_test(#ws3 == 3, "Expected 3 word starts in 'x = 42', got " .. #ws3)
assert_test(ws3[1].col == 0, "x at col 0, got " .. ws3[1].col)
assert_test(ws3[2].col == 2, "= at col 2, got " .. ws3[2].col)
assert_test(ws3[3].col == 4, "42 at col 4, got " .. ws3[3].col)

-- Test 7: find_word_starts with leading whitespace
-- "    indented" -> indented(4) — one word
local ws4 = word._find_word_starts({ "    indented" })
assert_test(#ws4 == 1, "Expected 1 word start in '    indented', got " .. #ws4)
assert_test(ws4[1].col == 4, "indented at col 4, got " .. ws4[1].col)

-- Test 8: find_word_starts multiline
local ws5 = word._find_word_starts({ "foo bar", "baz" })
assert_test(#ws5 == 3, "Expected 3 word starts across 2 lines, got " .. #ws5)
assert_test(
	ws5[3].row == 1 and ws5[3].col == 0,
	"baz should be at (1,0), got (" .. ws5[3].row .. "," .. ws5[3].col .. ")"
)

-- Test 9: find_word_starts with empty line
local ws6 = word._find_word_starts({ "foo", "", "bar" })
assert_test(#ws6 == 2, "Expected 2 word starts (empty line skipped), got " .. #ws6)

-- Test 10: compute_optimal works
-- Manually set up: if start and target are 3 word-hops apart, optimal = 3
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_word")
local challenge = word.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

local opt = word.compute_optimal(challenge.start_pos, challenge.target)
assert_test(opt >= 3, "Optimal moves should be >= 3, got " .. opt)

-- Test 11: Target is at a word start position
local all_ws = word._find_word_starts(challenge.snippet_lines)
local target_is_word_start = false
for _, ws in ipairs(all_ws) do
	if ws.row == challenge.target.row and ws.col == challenge.target.col then
		target_is_word_start = true
		break
	end
end
assert_test(
	target_is_word_start,
	"Target (" .. challenge.target.row .. "," .. challenge.target.col .. ") must be a word start"
)

-- Test 12: Start position is at a word start position
local start_is_word_start = false
for _, ws in ipairs(all_ws) do
	if ws.row == challenge.start_pos.row and ws.col == challenge.start_pos.col then
		start_is_word_start = true
		break
	end
end
assert_test(
	start_is_word_start,
	"Start (" .. challenge.start_pos.row .. "," .. challenge.start_pos.col .. ") must be a word start"
)

-- Test 13: Run 50 generations without crashes
for i = 1, 50 do
	local ch = word.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")

	-- Verify target is always at a word start
	local gen_ws = word._find_word_starts(ch.snippet_lines)
	local found = false
	for _, ws in ipairs(gen_ws) do
		if ws.row == ch.target.row and ws.col == ch.target.col then
			found = true
			break
		end
	end
	assert_test(
		found,
		"Generation " .. i .. ": target (" .. ch.target.row .. "," .. ch.target.col .. ") not a word start"
	)
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_word_movement")
