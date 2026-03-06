-- vimteacher/lessons/change_words.lua
-- Eighth lesson: Change words with cw, cW

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Change Words: {{cw}}, {{cW}}",
	type = "insert",
	allowed_keys = { "c" },
	allowed_modify_keys = {},
	challenges_required = 10,
	template_tokens = {
		cw = "cw",
		cW = "cW",
		Esc = "Esc",
	},
	description_template = {
	"The change operator (c) deletes text AND enters insert mode,",
	"so you can type a replacement in one smooth motion.",
	"",
	"  {{cw}} = change word: delete to next word, then type replacement",
	"  {{cW}} = change WORD: delete to next WORD, then type replacement",
	"",
	"Think of it as: c = d (delete) + i (insert) combined.",
	"",
	"Navigate to the target, press {{cw}}, type the fix, press {{Esc}}.",
	},
	hint_template = {
		"[{{cw}}] Change word  [{{cW}}] Change WORD  [{{Esc}}] Return to normal mode",
	},
})

-- Pre-defined challenge pool.
-- cw: changes (deletes + insert) from cursor to next word boundary
-- cW: changes from cursor to next WORD boundary (space)
local CHALLENGES = {
	-- Challenge 1: cw — change 'fetch' to 'get'
	{
		snippet_lines = {
			"function validate(input) {",
			"  const data = fetch(input);",
			"  return data;",
			"}",
		},
		expected_lines = {
			"function validate(input) {",
			"  const data = get(input);",
			"  return data;",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 3, col = 0 },
		key = "cw",
		char = "get",
	},

	-- Challenge 2: cw — change 'temp' to 'result'
	{
		snippet_lines = {
			"function process() {",
			"  const temp = compute();",
			"  return temp;",
			"}",
		},
		expected_lines = {
			"function process() {",
			"  const result = compute();",
			"  return temp;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "cw",
		char = "result",
	},

	-- Challenge 3: cw — change 'var' to 'const'
	{
		snippet_lines = {
			"function init() {",
			"  var count = 0;",
			"  return count;",
			"}",
		},
		expected_lines = {
			"function init() {",
			"  const count = 0;",
			"  return count;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "cw",
		char = "const",
	},

	-- Challenge 4: cw — change 'log' to 'warn'
	{
		snippet_lines = {
			"function notify(msg) {",
			"  console.log(msg);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function notify(msg) {",
			"  console.warn(msg);",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 10 },
		start_pos = { row = 0, col = 0 },
		key = "cw",
		char = "warn",
	},

	-- Challenge 5: cw — change 'items' to 'users'
	{
		snippet_lines = {
			"function loop(list) {",
			"  for (const item of items) {",
			"    console.log(item);",
			"  }",
			"}",
		},
		expected_lines = {
			"function loop(list) {",
			"  for (const item of users) {",
			"    console.log(item);",
			"  }",
			"}",
		},
		target = { row = 1, col = 21 },
		start_pos = { row = 4, col = 0 },
		key = "cw",
		char = "users",
	},

	-- Challenge 6: cW — change 'data.users[0]' to 'result'
	{
		snippet_lines = {
			"function getFirst() {",
			"  return data.users[0] || null;",
			"}",
		},
		expected_lines = {
			"function getFirst() {",
			"  return result || null;",
			"}",
		},
		target = { row = 1, col = 9 },
		start_pos = { row = 2, col = 0 },
		key = "cW",
		char = "result",
	},

	-- Challenge 7: cw — change 'oldValue' to 'newValue'
	{
		snippet_lines = {
			"function update() {",
			"  const oldValue = 1;",
			"  return oldValue;",
			"}",
		},
		expected_lines = {
			"function update() {",
			"  const newValue = 1;",
			"  return oldValue;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "cw",
		char = "newValue",
	},

	-- Challenge 8: cW — change 'http://localhost:3000;' to 'https://api.example.com;'
	{
		snippet_lines = {
			"function connect() {",
			"  const url = http://localhost:3000;",
			"  return fetch(url);",
			"}",
		},
		expected_lines = {
			"function connect() {",
			"  const url = https://api.example.com;",
			"  return fetch(url);",
			"}",
		},
		target = { row = 1, col = 14 },
		start_pos = { row = 3, col = 0 },
		key = "cW",
		char = "https://api.example.com;",
	},

	-- Challenge 9: cw — change 'false' to 'true'
	{
		snippet_lines = {
			"function toggle() {",
			"  let enabled = false;",
			"  return enabled;",
			"}",
		},
		expected_lines = {
			"function toggle() {",
			"  let enabled = true;",
			"  return enabled;",
			"}",
		},
		target = { row = 1, col = 16 },
		start_pos = { row = 0, col = 0 },
		key = "cw",
		char = "true",
	},

	-- Challenge 10: cw — change 'error' to 'warning'
	{
		snippet_lines = {
			"function alert(msg) {",
			"  console.error(msg);",
			"  return false;",
			"}",
		},
		expected_lines = {
			"function alert(msg) {",
			"  console.warning(msg);",
			"  return false;",
			"}",
		},
		target = { row = 1, col = 10 },
		start_pos = { row = 3, col = 0 },
		key = "cw",
		char = "warning",
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- For cw/cW, user navigates to target (0, 1, or 2 moves) then executes operator (+1).
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	local moves = 0
	if start_pos.row ~= target.row then
		moves = moves + 1
	end
	if start_pos.col ~= target.col then
		moves = moves + 1
	end
	return moves + 1 -- +1 for the cw/cW operation
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char}
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
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
