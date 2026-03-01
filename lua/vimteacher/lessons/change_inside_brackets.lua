-- vimteacher/lessons/change_inside_brackets.lua
-- Lesson: Change inside brackets with ci(, ci[, ci{

local M = {}
local optimal = require("vimteacher.optimal")

M.title = "Change Inside: ci(, ci[, ci{"
M.type = "insert"
M.allowed_keys = { "c" }
M.challenges_required = 10

M.description = {
	"Change text inside brackets:",
	"",
	"  ci(  = change inside parentheses",
	"  ci[  = change inside square brackets",
	"  ci{  = change inside curly braces",
	"",
	"Navigate to the target inside brackets and use the indicated key.",
	"Brackets are kept; only the contents are replaced.",
}

M.hint_lines = {
	"[ci(] Change inside ()  [ci[] Change inside []  [ci{] Change inside {}  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool.
-- Each challenge has:
--   key: "ci(", "ci[", or "ci{"
--   char: replacement text to type after ci( command
--   target: position inside the brackets (cursor placement)
--   Brackets are kept; contents between brackets are replaced with char
local CHALLENGES = {
	-- Challenge 1: ci( — change "old_msg" to "new_msg" in log()
	{
		snippet_lines = {
			"function notify(user) {",
			"  log(old_msg);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function notify(user) {",
			"  log(new_msg);",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 7 },
		start_pos = { row = 3, col = 0 },
		key = "ci(",
		char = "new_msg",
	},

	-- Challenge 2: ci[ — change "0" to "index" in array access
	{
		snippet_lines = {
			"function getFirst(items) {",
			"  const value = items[0];",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function getFirst(items) {",
			"  const value = items[index];",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 22 },
		start_pos = { row = 0, col = 0 },
		key = "ci[",
		char = "index",
	},

	-- Challenge 3: ci{ — change "x: 1" to "count: 0" in object literal
	{
		snippet_lines = {
			"function initState() {",
			"  const config = {x: 1};",
			"  return config;",
			"}",
		},
		expected_lines = {
			"function initState() {",
			"  const config = {count: 0};",
			"  return config;",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 3, col = 0 },
		key = "ci{",
		char = "count: 0",
	},

	-- Challenge 4: ci( — change "a, b" to "x, y, z" in function params
	{
		snippet_lines = {
			"function calculate(a, b) {",
			"  return a + b;",
			"}",
		},
		expected_lines = {
			"function calculate(x, y, z) {",
			"  return a + b;",
			"}",
		},
		target = { row = 0, col = 20 },
		start_pos = { row = 2, col = 0 },
		key = "ci(",
		char = "x, y, z",
	},

	-- Challenge 5: ci[ — change "i" to "pos + 1" in array indexing
	{
		snippet_lines = {
			"function access(arr, pos) {",
			"  const elem = arr[i];",
			"  return elem;",
			"}",
		},
		expected_lines = {
			"function access(arr, pos) {",
			"  const elem = arr[pos + 1];",
			"  return elem;",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 0, col = 0 },
		key = "ci[",
		char = "pos + 1",
	},

	-- Challenge 6: ci{ — change "a: 1, b: 2" to "name: 'test'" in object
	{
		snippet_lines = {
			"function makeObj() {",
			"  return {a: 1, b: 2};",
			"}",
		},
		expected_lines = {
			"function makeObj() {",
			"  return {name: 'test'};",
			"}",
		},
		target = { row = 1, col = 11 },
		start_pos = { row = 2, col = 0 },
		key = "ci{",
		char = "name: 'test'",
	},

	-- Challenge 7: ci( — change "msg" to "error.message" in console.log
	{
		snippet_lines = {
			"function handleError(error) {",
			"  console.log(msg);",
			"  throw error;",
			"}",
		},
		expected_lines = {
			"function handleError(error) {",
			"  console.log(error.message);",
			"  throw error;",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 3, col = 0 },
		key = "ci(",
		char = "error.message",
	},

	-- Challenge 8: ci[ — change "key" to "id" in object access
	{
		snippet_lines = {
			"function lookup(obj) {",
			"  const result = obj[key];",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function lookup(obj) {",
			"  const result = obj[id];",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 23 },
		start_pos = { row = 0, col = 0 },
		key = "ci[",
		char = "id",
	},

	-- Challenge 9: ci{ — change empty object to "status: 'ok'"
	{
		snippet_lines = {
			"function createResponse() {",
			"  return {};",
			"}",
		},
		expected_lines = {
			"function createResponse() {",
			"  return {status: 'ok'};",
			"}",
		},
		target = { row = 1, col = 10 },
		start_pos = { row = 2, col = 0 },
		key = "ci{",
		char = "status: 'ok'",
	},

	-- Challenge 10: ci( — change "value" to "defaultValue || 0" in return statement
	{
		snippet_lines = {
			"function getValue() {",
			"  const result = compute();",
			"  return (value);",
			"}",
		},
		expected_lines = {
			"function getValue() {",
			"  const result = compute();",
			"  return (defaultValue || 0);",
			"}",
		},
		target = { row = 2, col = 11 },
		start_pos = { row = 0, col = 0 },
		key = "ci(",
		char = "defaultValue || 0",
	},
}

-- Track recently used challenges to avoid repetition
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
	current_snippet = c.snippet_lines
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
