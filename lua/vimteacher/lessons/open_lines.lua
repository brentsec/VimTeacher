-- vimteacher/lessons/open_lines.lua
-- Sixth lesson: Opening new lines with o and O

local M = {}

M.title = "Open New Lines: o, O"
M.type = "insert"
M.allowed_keys = { "o", "O" }
M.challenges_required = 10

M.description = {
	"The open commands create a new line and enter insert mode.",
	"",
	"  o = open a new line BELOW the cursor",
	"  O = open a new line ABOVE the cursor",
	"",
	"Navigate to the highlighted line, press o or O to add the",
	"missing line, type the text, then press <Esc>.",
}

M.hint_lines = {
	"[o] Open below  [O] Open above  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool. Each challenge has a "broken" snippet (missing a line)
-- and the expected fix (with the line present).
-- For `o` challenges: target is the line ABOVE where the new line goes
-- For `O` challenges: target is the line BELOW where the new line goes
-- `char` is the text to type WITHOUT indent (autoindent provides the leading spaces)
local CHALLENGES = {
	-- Challenge 1: o — add 'banana' after 'apple' in array
	{
		snippet_lines = {
			"const fruits = [",
			"  'apple',",
			"  'cherry',",
			"];",
		},
		expected_lines = {
			"const fruits = [",
			"  'apple',",
			"  'banana',",
			"  'cherry',",
			"];",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "o",
		char = "'banana',",
	},

	-- Challenge 2: o — add return statement after const msg
	{
		snippet_lines = {
			"function greet(name) {",
			"  const msg = 'Hello, ' + name;",
			"}",
		},
		expected_lines = {
			"function greet(name) {",
			"  const msg = 'Hello, ' + name;",
			"  return msg;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "o",
		char = "return msg;",
	},

	-- Challenge 3: o — add multiplier declaration after sum
	{
		snippet_lines = {
			"function calc(a, b) {",
			"  const sum = a + b;",
			"  return sum * multiplier;",
			"}",
		},
		expected_lines = {
			"function calc(a, b) {",
			"  const sum = a + b;",
			"  const multiplier = 2;",
			"  return sum * multiplier;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "o",
		char = "const multiplier = 2;",
	},

	-- Challenge 4: o — add 'green' after 'red' in colors
	{
		snippet_lines = {
			"const colors = [",
			"  'red',",
			"  'blue',",
			"];",
		},
		expected_lines = {
			"const colors = [",
			"  'red',",
			"  'green',",
			"  'blue',",
			"];",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "o",
		char = "'green',",
	},

	-- Challenge 5: o — add console.log after result
	{
		snippet_lines = {
			"function process(data) {",
			"  const result = transform(data);",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process(data) {",
			"  const result = transform(data);",
			"  console.log(result);",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "o",
		char = "console.log(result);",
	},

	-- Challenge 6: O — add path import before express import
	{
		snippet_lines = {
			"const express = require('express');",
			"const app = express();",
			"app.listen(3000);",
		},
		expected_lines = {
			"const path = require('path');",
			"const express = require('express');",
			"const app = express();",
			"app.listen(3000);",
		},
		target = { row = 0, col = 0 },
		start_pos = { row = 2, col = 0 },
		key = "O",
		char = "const path = require('path');",
	},

	-- Challenge 7: O — add 'apple' before 'banana' in fruits
	{
		snippet_lines = {
			"const items = [",
			"  'banana',",
			"  'cherry',",
			"];",
		},
		expected_lines = {
			"const items = [",
			"  'apple',",
			"  'banana',",
			"  'cherry',",
			"];",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "O",
		char = "'apple',",
	},

	-- Challenge 8: O — add prefix variable before return
	{
		snippet_lines = {
			"function format(items) {",
			"  return items.map(x => prefix + x);",
			"}",
		},
		expected_lines = {
			"function format(items) {",
			"  const prefix = '> ';",
			"  return items.map(x => prefix + x);",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "O",
		char = "const prefix = '> ';",
	},

	-- Challenge 9: O — add 'write tests' before 'review code'
	{
		snippet_lines = {
			"const tasks = [",
			"  'review code',",
			"  'deploy',",
			"];",
		},
		expected_lines = {
			"const tasks = [",
			"  'write tests',",
			"  'review code',",
			"  'deploy',",
			"];",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "O",
		char = "'write tests',",
	},

	-- Challenge 10: O — add validation comment before if statement
	{
		snippet_lines = {
			"function validate(input) {",
			"  if (input.length === 0) {",
			"    return false;",
			"  }",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function validate(input) {",
			"  // Validate input",
			"  if (input.length === 0) {",
			"    return false;",
			"  }",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 4, col = 0 },
		key = "O",
		char = "// Validate input",
	},
}

-- Track recently used challenges to avoid repetition
local recent_picker = require("vimteacher.recent")
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- o/O jump to a new line, so only row navigation matters.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end
	if start_pos.row == target.row then
		return 1
	end
	return 2
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char}
function M.generate_challenge(buf, ns_id)
	-- Build list of eligible indices (not recently used)
	local idx = recent_picker.pick_avoiding_recent(#CHALLENGES, recent, MAX_RECENT)

	local c = CHALLENGES[idx]
	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		char = c.char,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
