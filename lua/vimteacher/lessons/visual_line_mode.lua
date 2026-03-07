-- vimteacher/lessons/visual_line_mode.lua
-- Visual Line Mode: V + d, V + c

local base = require("vimteacher.lessons.base")
local pool = require("vimteacher.lessons.pool")

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

local challenge_pool = pool.new(CHALLENGES, {
	transform_challenge = function(challenge)
		local key = challenge.key
		if key == "Vd" or key == "Vc" then
			challenge.highlight_rows = { challenge.target.row }
		elseif key == "Vjd" then
			challenge.highlight_rows = { challenge.target.row, challenge.target.row + 1 }
		elseif key == "Vjjd" then
			challenge.highlight_rows = { challenge.target.row, challenge.target.row + 1, challenge.target.row + 2 }
		end
		return challenge
	end,
})

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
