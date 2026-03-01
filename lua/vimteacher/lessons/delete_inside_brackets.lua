-- vimteacher/lessons/delete_inside_brackets.lua
-- Lesson: Delete inside brackets with di(, di[, di{

local M = {}
local optimal = require("vimteacher.optimal")

M.title = "Delete Inside: di(, di[, di{"
M.type = "insert"
M.allowed_keys = {}
M.allowed_modify_keys = { "d" }
M.challenges_required = 10

M.description = {
	"Delete text inside brackets without removing the brackets:",
	"",
	"  di(  = delete inside parentheses",
	"  di[  = delete inside square brackets",
	"  di{  = delete inside curly braces",
	"",
	"Place cursor anywhere inside the brackets and execute the command.",
	"The brackets remain, but their contents are deleted.",
}

M.hint_lines = {
	"[di(] Delete inside ()  [di[] Delete inside []  [di{] Delete inside {}",
}

-- Pre-defined challenge pool.
-- Each challenge targets a specific bracket pair on a line.
-- target.col should be positioned somewhere inside the brackets.
local CHALLENGES = {
	-- Challenge 1: di( — clear function call arguments
	{
		snippet_lines = {
			"function initialize(config) {",
			"  console.log(data.name);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function initialize(config) {",
			"  console.log();",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 3, col = 0 },
		key = "di(",
	},

	-- Challenge 2: di[ — clear array contents
	{
		snippet_lines = {
			"function getData() {",
			"  const items = [1, 2, 3, 4];",
			"  return items;",
			"}",
		},
		expected_lines = {
			"function getData() {",
			"  const items = [];",
			"  return items;",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 0, col = 0 },
		key = "di[",
	},

	-- Challenge 3: di{ — clear object contents
	{
		snippet_lines = {
			"function createUser() {",
			"  const user = { name: 'John', age: 30 };",
			"  return user;",
			"}",
		},
		expected_lines = {
			"function createUser() {",
			"  const user = {};",
			"  return user;",
			"}",
		},
		target = { row = 1, col = 20 },
		start_pos = { row = 3, col = 0 },
		key = "di{",
	},

	-- Challenge 4: di( — clear nested function call
	{
		snippet_lines = {
			"function process() {",
			"  const result = parseInt(value);",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process() {",
			"  const result = parseInt();",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 28 },
		start_pos = { row = 0, col = 0 },
		key = "di(",
	},

	-- Challenge 5: di[ — clear array index access
	{
		snippet_lines = {
			"function getFirst(arr) {",
			"  const first = arr[0];",
			"  return first;",
			"}",
		},
		expected_lines = {
			"function getFirst(arr) {",
			"  const first = arr[];",
			"  return first;",
			"}",
		},
		target = { row = 1, col = 21 },
		start_pos = { row = 3, col = 0 },
		key = "di[",
	},

	-- Challenge 6: di{ — clear inline object
	{
		snippet_lines = {
			"function config() {",
			"  return { port: 3000, host: 'localhost' };",
			"}",
		},
		expected_lines = {
			"function config() {",
			"  return {};",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 0, col = 0 },
		key = "di{",
	},

	-- Challenge 7: di( — clear method call arguments
	{
		snippet_lines = {
			"function update(data) {",
			"  obj.method(arg1, arg2, arg3);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function update(data) {",
			"  obj.method();",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 3, col = 0 },
		key = "di(",
	},

	-- Challenge 8: di[ — clear array literal
	{
		snippet_lines = {
			"function getColors() {",
			"  const colors = ['red', 'green', 'blue'];",
			"  return colors;",
			"}",
		},
		expected_lines = {
			"function getColors() {",
			"  const colors = [];",
			"  return colors;",
			"}",
		},
		target = { row = 1, col = 25 },
		start_pos = { row = 0, col = 0 },
		key = "di[",
	},

	-- Challenge 9: di{ — clear template object
	{
		snippet_lines = {
			"function template() {",
			"  const obj = { id: 1, status: 'active' };",
			"  return obj;",
			"}",
		},
		expected_lines = {
			"function template() {",
			"  const obj = {};",
			"  return obj;",
			"}",
		},
		target = { row = 1, col = 23 },
		start_pos = { row = 3, col = 0 },
		key = "di{",
	},

	-- Challenge 10: di( — clear constructor arguments
	{
		snippet_lines = {
			"function create() {",
			"  const instance = new MyClass(param1, param2);",
			"  return instance;",
			"}",
		},
		expected_lines = {
			"function create() {",
			"  const instance = new MyClass();",
			"  return instance;",
			"}",
		},
		target = { row = 1, col = 35 },
		start_pos = { row = 0, col = 0 },
		key = "di(",
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
		return optimal.manhattan(start_pos, target) + 1
	end
	return optimal.nav_cost(current_snippet, start_pos, target)
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key}
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
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
