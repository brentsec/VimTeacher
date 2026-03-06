-- vimteacher/lessons/delete_words.lua
-- Lesson: Delete Words with dw and dW

local M = {}
local optimal = require("vimteacher.optimal")

M.title = "Delete Words: dw, dW"
M.type = "insert"
M.allowed_keys = {}
M.allowed_modify_keys = { "d" }
M.challenges_required = 10

M.description = {
	"The delete operator (d) removes text. Combine it with a motion:",
	"",
	"  dw  = delete from cursor to start of next word",
	"  dW  = delete from cursor to start of next WORD",
	"       (a WORD is everything until the next space)",
	"",
	"Tip: Deleted text is saved to your clipboard (like cut).",
	"If you start d by mistake, press Esc to cancel.",
	"",
	"Navigate to the target and delete the highlighted word.",
}

M.hint_lines = {
	"[dw] Delete word  [dW] Delete WORD  [Esc] Cancel operator",
}

-- Pre-defined challenge pool.
-- dw: deletes from cursor to next word boundary (word chars + trailing space)
-- dW: deletes from cursor to next whitespace (WORD + trailing space)
local CHALLENGES = {
	-- Challenge 1: dw — delete 'temp ' from variable name
	{
		snippet_lines = {
			"function process(data) {",
			"  const temp result = data.value;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process(data) {",
			"  const result = data.value;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 3, col = 0 },
		key = "dw",
	},

	-- Challenge 2: dw — delete 'old ' word
	{
		snippet_lines = {
			"let items = getList();",
			"let old items = getList();",
			"return items;",
		},
		expected_lines = {
			"let items = getList();",
			"let items = getList();",
			"return items;",
		},
		target = { row = 1, col = 4 },
		start_pos = { row = 0, col = 0 },
		key = "dw",
	},

	-- Challenge 3: dw — delete 'DEBUG ' from constant name
	{
		snippet_lines = {
			"const PORT = 8080;",
			"const DEBUG mode = true;",
			"const HOST = 'localhost';",
		},
		expected_lines = {
			"const PORT = 8080;",
			"const mode = true;",
			"const HOST = 'localhost';",
		},
		target = { row = 1, col = 6 },
		start_pos = { row = 2, col = 0 },
		key = "dw",
	},

	-- Challenge 4: dw — delete 'unused ' from variable
	{
		snippet_lines = {
			"function cleanup() {",
			"  const unused variable = null;",
			"  return variable;",
			"}",
		},
		expected_lines = {
			"function cleanup() {",
			"  const variable = null;",
			"  return variable;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "dw",
	},

	-- Challenge 5: dw — delete 'test ' from variable name
	{
		snippet_lines = {
			"function verify() {",
			"  let test value = compute();",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function verify() {",
			"  let value = compute();",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 6 },
		start_pos = { row = 3, col = 0 },
		key = "dw",
	},

	-- Challenge 6: dW — delete 'data.users[0].name' expression
	{
		snippet_lines = {
			"function getName() {",
			"  const result = data.users[0].name value;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function getName() {",
			"  const result = value;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 0, col = 0 },
		key = "dW",
	},

	-- Challenge 7: dW — delete URL from assignment
	{
		snippet_lines = {
			"const baseUrl = 'http://example.com';",
			"const apiUrl = 'http://api.example.com/v1' endpoint;",
			"return apiUrl;",
		},
		expected_lines = {
			"const baseUrl = 'http://example.com';",
			"const apiUrl = endpoint;",
			"return apiUrl;",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 2, col = 0 },
		key = "dW",
	},

	-- Challenge 8: dW — delete complex expression
	{
		snippet_lines = {
			"function calculate() {",
			"  const value = Math.floor(x/10)*100 result;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function calculate() {",
			"  const value = result;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 16 },
		start_pos = { row = 0, col = 0 },
		key = "dW",
	},

	-- Challenge 9: dw — delete 'extra ' prefix
	{
		snippet_lines = {
			"function update() {",
			"  const extra data = fetch();",
			"  return data;",
			"}",
		},
		expected_lines = {
			"function update() {",
			"  const data = fetch();",
			"  return data;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 3, col = 0 },
		key = "dw",
	},

	-- Challenge 10: dW — delete file path
	{
		snippet_lines = {
			"const configPath = './config.json';",
			"const dataPath = '../data/users.json' file;",
			"return dataPath;",
		},
		expected_lines = {
			"const configPath = './config.json';",
			"const dataPath = file;",
			"return dataPath;",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 0, col = 0 },
		key = "dW",
	},
}

-- Track recently used challenges to avoid repetition
local recent_picker = require("vimteacher.recent")
local recent = {}
local MAX_RECENT = 5
local current_snippet = nil

function M._compute_nav_optimal(lines, start_pos, target)
	return optimal.nav_cost(lines, start_pos, target)
end

function M.compute_optimal(start_pos, target)
	if not current_snippet then
		return optimal.manhattan(start_pos, target)
	end
	return M._compute_nav_optimal(current_snippet, start_pos, target)
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
