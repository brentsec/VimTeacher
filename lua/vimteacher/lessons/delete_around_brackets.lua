-- vimteacher/lessons/delete_around_brackets.lua
-- Lesson: Delete Around brackets with da(, da[, da{

local M = {}
local optimal = require("vimteacher.optimal")

M.title = "Delete Around: da(, da[, da{"
M.type = "insert"
M.allowed_modify_keys = { "d" }
M.challenges_required = 10

M.description = {
	"Delete bracket pairs AND their contents with 'da' commands:",
	"",
	"  da( = delete around parentheses: removes () and everything inside",
	"  da[ = delete around square brackets: removes [] and everything inside",
	"  da{ = delete around curly braces: removes {} and everything inside",
	"",
	"Navigate to the green target inside the brackets and use the indicated command.",
}

M.hint_lines = {
	"[da(] Delete around ()  [da[] Delete around []  [da{] Delete around {}",
}

-- Pre-defined challenge pool.
-- da(, da[, da{ delete the bracket pair AND all contents between them
local CHALLENGES = {
	-- Challenge 1: da( — remove (msg) from console.log(msg)
	{
		snippet_lines = {
			"function debug(msg) {",
			"  console.log(msg);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function debug(msg) {",
			"  console.log;",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 3, col = 0 },
		key = "da(",
	},

	-- Challenge 2: da( — remove (url) from fetch(url)
	{
		snippet_lines = {
			"async function getData(url) {",
			"  const response = await fetch(url);",
			"  return response.json();",
			"}",
		},
		expected_lines = {
			"async function getData(url) {",
			"  const response = await fetch;",
			"  return response.json();",
			"}",
		},
		target = { row = 1, col = 33 },
		start_pos = { row = 0, col = 0 },
		key = "da(",
	},

	-- Challenge 3: da( — remove (a, b) from add(a, b)
	{
		snippet_lines = {
			"function calculate() {",
			"  const sum = add(a, b);",
			"  return sum;",
			"}",
		},
		expected_lines = {
			"function calculate() {",
			"  const sum = add;",
			"  return sum;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 3, col = 0 },
		key = "da(",
	},

	-- Challenge 4: da[ — remove [0] from items[0]
	{
		snippet_lines = {
			"function getFirst(items) {",
			"  const first = items[0];",
			"  return first;",
			"}",
		},
		expected_lines = {
			"function getFirst(items) {",
			"  const first = items;",
			"  return first;",
			"}",
		},
		target = { row = 1, col = 23 },
		start_pos = { row = 0, col = 0 },
		key = "da[",
	},

	-- Challenge 5: da[ — remove [index] from array[index]
	{
		snippet_lines = {
			"function getValue(array, index) {",
			"  return array[index];",
			"}",
		},
		expected_lines = {
			"function getValue(array, index) {",
			"  return array;",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 2, col = 0 },
		key = "da[",
	},

	-- Challenge 6: da[ — remove ['key'] from obj['key']
	{
		snippet_lines = {
			"function access(obj) {",
			"  const value = obj['key'];",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function access(obj) {",
			"  const value = obj;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 21 },
		start_pos = { row = 0, col = 0 },
		key = "da[",
	},

	-- Challenge 7: da{ — remove { name } from const { name }
	{
		snippet_lines = {
			"function extract(data) {",
			"  const { name } = data;",
			"  return name;",
			"}",
		},
		expected_lines = {
			"function extract(data) {",
			"  const  = data;",
			"  return name;",
			"}",
		},
		target = { row = 1, col = 10 },
		start_pos = { row = 3, col = 0 },
		key = "da{",
	},

	-- Challenge 8: da{ — remove { a, b } from const { a, b }
	{
		snippet_lines = {
			"function destructure(obj) {",
			"  const { a, b } = obj;",
			"  return a + b;",
			"}",
		},
		expected_lines = {
			"function destructure(obj) {",
			"  const  = obj;",
			"  return a + b;",
			"}",
		},
		target = { row = 1, col = 12 },
		start_pos = { row = 0, col = 0 },
		key = "da{",
	},

	-- Challenge 9: da( — remove (config) from init(config)
	{
		snippet_lines = {
			"function setup() {",
			"  init(config);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function setup() {",
			"  init;",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 7 },
		start_pos = { row = 3, col = 0 },
		key = "da(",
	},

	-- Challenge 10: da[ — remove [i] from list[i]
	{
		snippet_lines = {
			"function iterate(list) {",
			"  for (let i = 0; i < list.length; i++) {",
			"    console.log(list[i]);",
			"  }",
			"}",
		},
		expected_lines = {
			"function iterate(list) {",
			"  for (let i = 0; i < list.length; i++) {",
			"    console.log(list);",
			"  }",
			"}",
		},
		target = { row = 2, col = 21 },
		start_pos = { row = 0, col = 0 },
		key = "da[",
	},
}

-- Track recently used challenges to avoid repetition
local recent_picker = require("vimteacher.recent")
local recent = {}
local MAX_RECENT = 5
local current_snippet = nil

--- Compute the minimum (optimal) moves between two positions.
--- Uses motion-aware shortest-path scoring on the current snippet.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if not current_snippet then
		return optimal.manhattan(start_pos, target)
	end
	return optimal.nav_cost(current_snippet, start_pos, target)
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key}
function M.generate_challenge(buf, ns_id)
	-- Build list of eligible indices (not recently used)
	local idx = recent_picker.pick_avoiding_recent(#CHALLENGES, recent, MAX_RECENT)

	local c = CHALLENGES[idx]
	current_snippet = c.snippet_lines
	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
