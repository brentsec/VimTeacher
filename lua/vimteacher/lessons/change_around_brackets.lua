-- vimteacher/lessons/change_around_brackets.lua
-- Lesson: Change around brackets with ca(, ca[, ca{

local M = {}
local pool = require("vimteacher.lessons.pool")

M.title = "Change Around: ca(, ca[, ca{"
M.type = "insert"
M.allowed_keys = { "c" }
M.challenges_required = 10

M.description = {
	"Change around brackets deletes brackets and their contents:",
	"",
	"  ca( = delete parentheses and contents, enter insert mode",
	"  ca[ = delete square brackets and contents, enter insert mode",
	"  ca{ = delete curly braces and contents, enter insert mode",
	"",
	"Navigate to the green target inside the brackets and use the indicated key.",
}

M.hint_lines = {
	"[ca(] Change around (  [ca[] Change around [  [ca{] Change around {  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool.
-- Each challenge has key (ca(, ca[, or ca{) and char (replacement text)
-- The operation deletes the bracket pair AND contents, then inserts char
local CHALLENGES = {
	-- Challenge 1: ca( — change (old_val + 1) to new_val
	{
		snippet_lines = {
			"function process(args) {",
			"  const result = (old_val + 1);",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process(args) {",
			"  const result = new_val;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 3, col = 0 },
		key = "ca(",
		char = "new_val",
	},

	-- Challenge 2: ca( — change (x * scale) to offset
	{
		snippet_lines = {
			"function draw(x, y) {",
			"  const pos = (x * scale);",
			"  render(pos);",
			"}",
		},
		expected_lines = {
			"function draw(x, y) {",
			"  const pos = offset;",
			"  render(pos);",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 3, col = 0 },
		key = "ca(",
		char = "offset",
	},

	-- Challenge 3: ca( — change (timeout / 1000) to seconds
	{
		snippet_lines = {
			"function init(config) {",
			"  const delay = (timeout / 1000);",
			"  return delay;",
			"}",
		},
		expected_lines = {
			"function init(config) {",
			"  const delay = seconds;",
			"  return delay;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 0, col = 0 },
		key = "ca(",
		char = "seconds",
	},

	-- Challenge 4: ca[ — change [0] to .first
	{
		snippet_lines = {
			"function getItem(arr) {",
			"  const item = arr[0];",
			"  return item;",
			"}",
		},
		expected_lines = {
			"function getItem(arr) {",
			"  const item = arr.first;",
			"  return item;",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 3, col = 0 },
		key = "ca[",
		char = ".first",
	},

	-- Challenge 5: ca[ — change [index] to .at(index)
	{
		snippet_lines = {
			"function lookup(data, index) {",
			"  return data[index];",
			"}",
		},
		expected_lines = {
			"function lookup(data, index) {",
			"  return data.at(index);",
			"}",
		},
		target = { row = 1, col = 14 },
		start_pos = { row = 0, col = 0 },
		key = "ca[",
		char = ".at(index)",
	},

	-- Challenge 6: ca[ — change [key] to .key
	{
		snippet_lines = {
			"function getValue(obj) {",
			"  const val = obj[key];",
			"  return val;",
			"}",
		},
		expected_lines = {
			"function getValue(obj) {",
			"  const val = obj.key;",
			"  return val;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 3, col = 0 },
		key = "ca[",
		char = ".key",
	},

	-- Challenge 7: ca{ — change {a, b} to props
	{
		snippet_lines = {
			"function merge(obj) {",
			"  const result = {a, b};",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function merge(obj) {",
			"  const result = props;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 0, col = 0 },
		key = "ca{",
		char = "props",
	},

	-- Challenge 8: ca{ — change {x: 1} to defaults
	{
		snippet_lines = {
			"function setup() {",
			"  const opts = {x: 1};",
			"  return opts;",
			"}",
		},
		expected_lines = {
			"function setup() {",
			"  const opts = defaults;",
			"  return opts;",
			"}",
		},
		target = { row = 1, col = 16 },
		start_pos = { row = 3, col = 0 },
		key = "ca{",
		char = "defaults",
	},

	-- Challenge 9: ca{ — change {name, age} to person
	{
		snippet_lines = {
			"function display(data) {",
			"  const user = {name, age};",
			"  console.log(user);",
			"}",
		},
		expected_lines = {
			"function display(data) {",
			"  const user = person;",
			"  console.log(user);",
			"}",
		},
		target = { row = 1, col = 16 },
		start_pos = { row = 0, col = 0 },
		key = "ca{",
		char = "person",
	},

	-- Challenge 10: ca( — change (a + b) to sum
	{
		snippet_lines = {
			"function compute(a, b) {",
			"  const total = (a + b);",
			"  return total;",
			"}",
		},
		expected_lines = {
			"function compute(a, b) {",
			"  const total = sum;",
			"  return total;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 3, col = 0 },
		key = "ca(",
		char = "sum",
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
