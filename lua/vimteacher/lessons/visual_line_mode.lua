-- vimteacher/lessons/visual_line_mode.lua
-- Visual Line Mode: V + d, V + c

local base = require("vimteacher.lessons.base")
local optimal = require("vimteacher.optimal")

local M = base.define({
	title_template = "Visual Line Mode: {{V}} + {{d}}, {{V}} + {{c}}",
	type = "insert",
	allowed_keys = { "c" },
	allowed_modify_keys = { "d" },
	allowed_visual_keys = { "V" },
	challenges_required = 10,
	template_tokens = {
		V = "V",
		j = "j",
		k = "k",
		d = "d",
		c = "c",
		Esc = "Esc",
	},
	description_template = {
	"Visual line mode lets you select and delete entire lines:",
	"",
	"  {{V}}    = enter visual line mode (select current line)",
	"  {{j}}/{{k}}  = expand selection down/up",
	"  {{d}}    = delete selected lines",
	"  {{c}}    = delete selected lines and enter insert mode",
	"",
	"Navigate to the green target and use the indicated key sequence.",
	},
	hint_template = {
		"[{{V}}] Visual line  [{{j}}/{{k}}] Expand selection  [{{d}}] Delete  [{{c}}] Change  [{{Esc}}] Return to normal mode",
	},
})

-- Pre-defined challenge pool.
-- Vd: select 1 line and delete (removes 1 line)
-- Vjd: select 2 lines and delete (removes 2 lines)
-- Vjjd: select 3 lines and delete (removes 3 lines)
-- Vc: select 1 line, delete and insert replacement
local CHALLENGES = {
	-- Challenge 1: Vd — delete debug line
	{
		snippet_lines = {
			"function process(data) {",
			"  const result = transform(data);",
			"  console.log('DEBUG:', result);",
			"  return result;",
			"}",
			"",
			"module.exports = process;",
		},
		expected_lines = {
			"function process(data) {",
			"  const result = transform(data);",
			"  return result;",
			"}",
			"",
			"module.exports = process;",
		},
		target = { row = 2, col = 2 },
		start_pos = { row = 6, col = 0 },
		key = "Vd",
	},

	-- Challenge 2: Vd — delete temporary variable line
	{
		snippet_lines = {
			"const config = {",
			"  port: 3000,",
			"  host: 'localhost',",
			"  debug: false,",
			"  timeout: 5000,",
			"  retries: 3,",
			"};",
		},
		expected_lines = {
			"const config = {",
			"  port: 3000,",
			"  host: 'localhost',",
			"  timeout: 5000,",
			"  retries: 3,",
			"};",
		},
		target = { row = 3, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "Vd",
	},

	-- Challenge 3: Vjd — delete 2 comment lines
	{
		snippet_lines = {
			"function authenticate(user) {",
			"  // TODO: implement proper auth",
			"  // For now just return true",
			"  return true;",
			"}",
			"",
			"export default authenticate;",
		},
		expected_lines = {
			"function authenticate(user) {",
			"  return true;",
			"}",
			"",
			"export default authenticate;",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 4, col = 0 },
		key = "Vjd",
	},

	-- Challenge 4: Vjd — delete 2 import lines
	{
		snippet_lines = {
			"import React from 'react';",
			"import { useState, useEffect } from 'react';",
			"import { useDebugValue } from 'react';",
			"",
			"function MyComponent() {",
			"  return <div>Hello</div>;",
			"}",
		},
		expected_lines = {
			"import React from 'react';",
			"",
			"function MyComponent() {",
			"  return <div>Hello</div>;",
			"}",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 6, col = 0 },
		key = "Vjd",
	},

	-- Challenge 5: Vjjd — delete 3 console.log lines
	{
		snippet_lines = {
			"function calculate(a, b) {",
			"  console.log('a:', a);",
			"  console.log('b:', b);",
			"  console.log('calculating...');",
			"  const result = a + b;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function calculate(a, b) {",
			"  const result = a + b;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 6, col = 0 },
		key = "Vjjd",
	},

	-- Challenge 6: Vjjd — delete 3 error handling lines
	{
		snippet_lines = {
			"async function fetchData(url) {",
			"  try {",
			"    return await fetch(url);",
			"  } catch (error) {",
			"    console.error('Failed:', error);",
			"    throw error;",
			"  }",
			"}",
		},
		expected_lines = {
			"async function fetchData(url) {",
			"  try {",
			"    return await fetch(url);",
			"  }",
			"}",
		},
		target = { row = 3, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "Vjjd",
	},

	-- Challenge 7: Vc — replace comment with actual code
	{
		snippet_lines = {
			"function init(config) {",
			"  // validate config here",
			"  return config;",
			"}",
			"",
			"module.exports = init;",
		},
		expected_lines = {
			"function init(config) {",
			"  if (!config) throw new Error('Invalid config');",
			"  return config;",
			"}",
			"",
			"module.exports = init;",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 5, col = 0 },
		key = "Vc",
		char = "  if (!config) throw new Error('Invalid config');",
	},

	-- Challenge 8: Vc — replace placeholder with real variable
	{
		snippet_lines = {
			"function getUserData() {",
			"  const PLACEHOLDER = fetchUser();",
			"  return PLACEHOLDER.profile;",
			"}",
			"",
			"export { getUserData };",
		},
		expected_lines = {
			"function getUserData() {",
			"  const userData = fetchUser();",
			"  return PLACEHOLDER.profile;",
			"}",
			"",
			"export { getUserData };",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "Vc",
		char = "  const userData = fetchUser();",
	},

	-- Challenge 9: Vd — delete old implementation
	{
		snippet_lines = {
			"class DataStore {",
			"  constructor() {",
			"    this.data = [];",
			"    this.legacyMode = true;",
			"  }",
			"",
			"  save(item) {",
			"    this.data.push(item);",
			"  }",
			"}",
		},
		expected_lines = {
			"class DataStore {",
			"  constructor() {",
			"    this.data = [];",
			"  }",
			"",
			"  save(item) {",
			"    this.data.push(item);",
			"  }",
			"}",
		},
		target = { row = 3, col = 4 },
		start_pos = { row = 9, col = 0 },
		key = "Vd",
	},

	-- Challenge 10: Vc — replace TODO with implementation
	{
		snippet_lines = {
			"function validate(input) {",
			"  if (!input) return false;",
			"  // TODO: add length check",
			"  return true;",
			"}",
			"",
			"export default validate;",
		},
		expected_lines = {
			"function validate(input) {",
			"  if (!input) return false;",
			"  if (input.length < 3) return false;",
			"  return true;",
			"}",
			"",
			"export default validate;",
		},
		target = { row = 2, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "Vc",
		char = "  if (input.length < 3) return false;",
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
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char?}
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

	-- Compute highlight_rows based on key
	local highlight_rows = {}
	if c.key == "Vd" or c.key == "Vc" then
		highlight_rows = { c.target.row }
	elseif c.key == "Vjd" then
		highlight_rows = { c.target.row, c.target.row + 1 }
	elseif c.key == "Vjjd" then
		highlight_rows = { c.target.row, c.target.row + 1, c.target.row + 2 }
	end

	local result = {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		highlight_rows = highlight_rows,
	}

	-- Include char field if present (for Vc challenges)
	if c.char then
		result.char = c.char
	end

	return result
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
