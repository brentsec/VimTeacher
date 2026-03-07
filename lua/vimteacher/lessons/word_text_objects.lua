-- vimteacher/lessons/word_text_objects.lua
-- Word text objects: diw, daw, ciw, caw

local base = require("vimteacher.lessons.base")
local pool = require("vimteacher.lessons.pool")

local M = base.define({
	title_template = "Word Objects: {{diw}}, {{daw}}, {{ciw}}, {{caw}}",
	type = "insert",
	allowed_keys = { "c" },
	allowed_modify_keys = { "d" },
	challenges_required = 10,
	template_tokens = {
		diw = "diw",
		daw = "daw",
		ciw = "ciw",
		caw = "caw",
		Esc = "Esc",
	},
	description_template = {
		"Word text objects let you operate on entire words efficiently:",
		"",
		"  {{diw}} = delete inner word (word only)",
		"  {{daw}} = delete a word (word + trailing space)",
		"  {{ciw}} = change inner word (delete word, insert replacement)",
		"  {{caw}} = change a word (delete word + space, insert replacement)",
		"",
		"Navigate to the green target (anywhere in the word) and use the indicated command.",
	},
	hint_template = {
		"[{{diw}}] Delete inner word  [{{daw}}] Delete a word  [{{ciw}}] Change inner word  [{{caw}}] Change a word  [{{Esc}}] Normal mode",
	},
})

-- Pre-defined challenge pool.
-- target.col should be somewhere IN the target word (not necessarily at start)
-- For diw: word is deleted, surrounding spaces preserved
-- For daw: word AND one trailing space deleted
-- For ciw/caw: deletion + replacement with char
local CHALLENGES = {
	-- Challenge 1: diw — delete 'wrong' in 'const wrong = value;'
	{
		snippet_lines = {
			"function calculate(x) {",
			"  const wrong = x * 2;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function calculate(x) {",
			"  const  = x * 2;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 10 }, -- middle of 'wrong'
		start_pos = { row = 0, col = 0 },
		key = "diw",
	},

	-- Challenge 2: daw — delete 'bad' and trailing space in 'const bad value'
	{
		snippet_lines = {
			"function process(data) {",
			"  const bad value = data;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function process(data) {",
			"  const value = data;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 9 }, -- middle of 'bad'
		start_pos = { row = 3, col = 0 },
		key = "daw",
	},

	-- Challenge 3: ciw — change 'error' to 'result'
	{
		snippet_lines = {
			"function transform(input) {",
			"  const error = input.trim();",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function transform(input) {",
			"  const result = input.trim();",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 9 }, -- middle of 'error'
		start_pos = { row = 0, col = 0 },
		key = "ciw",
		char = "result",
	},

	-- Challenge 4: caw — change 'tmp' to 'data' (including trailing space)
	{
		snippet_lines = {
			"function parse(text) {",
			"  let tmp value = text;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function parse(text) {",
			"  let data value = text;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 7 }, -- middle of 'tmp'
		start_pos = { row = 3, col = 0 },
		key = "caw",
		char = "data ",
	},

	-- Challenge 5: diw — delete 'invalid' in 'if (invalid) {'
	{
		snippet_lines = {
			"function validate(x) {",
			"  if (invalid) {",
			"    return false;",
			"  }",
			"}",
		},
		expected_lines = {
			"function validate(x) {",
			"  if () {",
			"    return false;",
			"  }",
			"}",
		},
		target = { row = 1, col = 8 }, -- middle of 'invalid'
		start_pos = { row = 0, col = 0 },
		key = "diw",
	},

	-- Challenge 6: daw — delete 'old' and space in 'return old value'
	{
		snippet_lines = {
			"function getValue() {",
			"  const x = 42;",
			"  return old value;",
			"}",
		},
		expected_lines = {
			"function getValue() {",
			"  const x = 42;",
			"  return value;",
			"}",
		},
		target = { row = 2, col = 10 }, -- middle of 'old'
		start_pos = { row = 0, col = 0 },
		key = "daw",
	},

	-- Challenge 7: ciw — change 'flag' to 'state'
	{
		snippet_lines = {
			"function check(input) {",
			"  const flag = input > 0;",
			"  return state;",
			"}",
		},
		expected_lines = {
			"function check(input) {",
			"  const state = input > 0;",
			"  return state;",
			"}",
		},
		target = { row = 1, col = 9 }, -- middle of 'flag'
		start_pos = { row = 3, col = 0 },
		key = "ciw",
		char = "state",
	},

	-- Challenge 8: caw — change 'temp' to 'output' (including space)
	{
		snippet_lines = {
			"function convert(str) {",
			"  const temp result = str;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function convert(str) {",
			"  const output result = str;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 10 }, -- middle of 'temp'
		start_pos = { row = 0, col = 0 },
		key = "caw",
		char = "output ",
	},

	-- Challenge 9: diw — delete 'extra' in 'const extra = 5;'
	{
		snippet_lines = {
			"function init() {",
			"  const extra = 5;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function init() {",
			"  const  = 5;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 10 }, -- middle of 'extra'
		start_pos = { row = 3, col = 0 },
		key = "diw",
	},

	-- Challenge 10: daw — delete 'unused' and space in 'let unused x = 1;'
	{
		snippet_lines = {
			"function setup() {",
			"  let unused x = 1;",
			"  return x;",
			"}",
		},
		expected_lines = {
			"function setup() {",
			"  let x = 1;",
			"  return x;",
			"}",
		},
		target = { row = 1, col = 8 }, -- middle of 'unused'
		start_pos = { row = 0, col = 0 },
		key = "daw",
	},
}

local challenge_pool = pool.new(CHALLENGES)

--- Compute the minimum (optimal) moves between two positions.
--- Uses motion-aware shortest-path scoring on the current snippet.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	return challenge_pool.nav_compute_optimal()(start_pos, target)
end
M.generate_challenge = challenge_pool.generate_challenge
M._get_challenges = challenge_pool.get_challenges

return M
