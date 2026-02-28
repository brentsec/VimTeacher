-- vimteacher/lessons/visual_mode_operators.lua
-- Visual mode operators: v + d, v + c

local M = {}

M.title = "Visual Operators: v + d, v + c"
M.type = "insert"
M.allowed_keys = { "c" }
M.allowed_modify_keys = { "d" }
M.allowed_visual_keys = { "v" }
M.challenges_required = 10

M.description = {
	"Visual mode operators for selecting and modifying text:",
	"",
	"  v  = enter visual mode (character-wise)",
	"  d  = delete selected text",
	"  c  = delete selected text and enter insert mode",
	"",
	"Navigate to the green target, press v, move to select, then d or c.",
}

M.hint_lines = {
	"[v] Visual mode  [d] Delete selection  [c] Change selection  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool.
-- vd: visual delete - select from target to select_end, then delete
-- vc: visual change - select from target to select_end, delete and insert char
local CHALLENGES = {
	-- Challenge 1: vd — delete "extra " in "const extra value = 42;"
	{
		snippet_lines = {
			"function init() {",
			"  const extra value = 42;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function init() {",
			"  const value = 42;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 8 },
		select_end = { row = 1, col = 13 },
		start_pos = { row = 3, col = 0 },
		key = "vd",
		char = "",
	},

	-- Challenge 2: vc — replace "old" with "new" in "const old = 10;"
	{
		snippet_lines = {
			"function setup() {",
			"  const old = 10;",
			"  return old;",
			"}",
		},
		expected_lines = {
			"function setup() {",
			"  const new = 10;",
			"  return old;",
			"}",
		},
		target = { row = 1, col = 8 },
		select_end = { row = 1, col = 10 },
		start_pos = { row = 0, col = 0 },
		key = "vc",
		char = "new",
	},

	-- Challenge 3: vd — delete "wrong_" in "function wrong_name()"
	{
		snippet_lines = {
			"function wrong_name() {",
			"  const data = fetch();",
			"  return data;",
			"}",
		},
		expected_lines = {
			"function name() {",
			"  const data = fetch();",
			"  return data;",
			"}",
		},
		target = { row = 0, col = 9 },
		select_end = { row = 0, col = 14 },
		start_pos = { row = 2, col = 0 },
		key = "vd",
		char = "",
	},

	-- Challenge 4: vc — replace "temp" with "result" in "let temp = 0;"
	{
		snippet_lines = {
			"function calculate() {",
			"  let temp = 0;",
			"  temp = compute();",
			"  return temp;",
			"}",
		},
		expected_lines = {
			"function calculate() {",
			"  let result = 0;",
			"  temp = compute();",
			"  return temp;",
			"}",
		},
		target = { row = 1, col = 6 },
		select_end = { row = 1, col = 9 },
		start_pos = { row = 4, col = 0 },
		key = "vc",
		char = "result",
	},

	-- Challenge 5: vd — delete "bad" in "const bad_value = 5;"
	{
		snippet_lines = {
			"function process() {",
			"  const bad_value = 5;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function process() {",
			"  const _value = 5;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 8 },
		select_end = { row = 1, col = 10 },
		start_pos = { row = 0, col = 0 },
		key = "vd",
		char = "",
	},

	-- Challenge 6: vc — replace "item" with "element" in "const item = list[0];"
	{
		snippet_lines = {
			"function loop() {",
			"  const item = list[0];",
			"  process(item);",
			"  return item;",
			"}",
		},
		expected_lines = {
			"function loop() {",
			"  const element = list[0];",
			"  process(item);",
			"  return item;",
			"}",
		},
		target = { row = 1, col = 8 },
		select_end = { row = 1, col = 11 },
		start_pos = { row = 4, col = 0 },
		key = "vc",
		char = "element",
	},

	-- Challenge 7: vd — delete "extra " in "return extra result;"
	{
		snippet_lines = {
			"function getData() {",
			"  const result = fetch();",
			"  return extra result;",
			"}",
		},
		expected_lines = {
			"function getData() {",
			"  const result = fetch();",
			"  return result;",
			"}",
		},
		target = { row = 2, col = 9 },
		select_end = { row = 2, col = 14 },
		start_pos = { row = 0, col = 0 },
		key = "vd",
		char = "",
	},

	-- Challenge 8: vc — replace "foo" with "data" in "const foo = {};"
	{
		snippet_lines = {
			"function init() {",
			"  const foo = {};",
			"  return foo;",
			"}",
		},
		expected_lines = {
			"function init() {",
			"  const data = {};",
			"  return foo;",
			"}",
		},
		target = { row = 1, col = 8 },
		select_end = { row = 1, col = 10 },
		start_pos = { row = 3, col = 0 },
		key = "vc",
		char = "data",
	},

	-- Challenge 9: vd — delete "unused_" in "let unused_var = 1;"
	{
		snippet_lines = {
			"function run() {",
			"  let unused_var = 1;",
			"  return var;",
			"}",
		},
		expected_lines = {
			"function run() {",
			"  let var = 1;",
			"  return var;",
			"}",
		},
		target = { row = 1, col = 6 },
		select_end = { row = 1, col = 12 },
		start_pos = { row = 3, col = 0 },
		key = "vd",
		char = "",
	},

	-- Challenge 10: vc — replace "name" with "label" in "const name = getTag();"
	{
		snippet_lines = {
			"function render() {",
			"  const name = getTag();",
			"  display(name);",
			"  return name;",
			"}",
		},
		expected_lines = {
			"function render() {",
			"  const label = getTag();",
			"  display(name);",
			"  return name;",
			"}",
		},
		target = { row = 1, col = 8 },
		select_end = { row = 1, col = 11 },
		start_pos = { row = 0, col = 0 },
		key = "vc",
		char = "label",
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- For visual mode operators, user must navigate to target, so Manhattan distance applies.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	return math.abs(start_pos.row - target.row) + math.abs(start_pos.col - target.col)
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char, select_end}
function M.generate_challenge(buf, ns_id)
	-- Build list of eligible indices (not recently used)
	local eligible = {}
	for i = 1, #CHALLENGES do
		local dominated = false
		for _, r in ipairs(recent) do
			if r == i then
				dominated = true
				break
			end
		end
		if not dominated then
			eligible[#eligible + 1] = i
		end
	end

	-- If all are recent, reset
	if #eligible == 0 then
		recent = {}
		for i = 1, #CHALLENGES do
			eligible[#eligible + 1] = i
		end
	end

	-- Pick random eligible challenge
	local idx = eligible[math.random(1, #eligible)]

	-- Update recency
	recent[#recent + 1] = idx
	if #recent > MAX_RECENT then
		table.remove(recent, 1)
	end

	local c = CHALLENGES[idx]
	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		char = c.char,
		select_end = { row = c.select_end.row, col = c.select_end.col },
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
