-- vimteacher/lessons/delete_multiple_lines.lua
-- Multi-line delete operations: dj, dk, d2j, d2k

local base = require("vimteacher.lessons.base")
local optimal = require("vimteacher.optimal")

local M = base.define({
	title_template = "Multi-Line Delete: {{delete_down}}, {{delete_up}}",
	type = "insert",
	allowed_keys = {},
	allowed_modify_keys = { "d" },
	challenges_required = 10,
	description_template = {
		"Delete multiple lines at once with d + motion:",
		"",
		"  {{delete_down}}  = delete current line and line below (2 lines)",
		"  {{delete_up}}  = delete current line and line above (2 lines)",
		"  {{delete_two_down}} = delete current line and 2 lines below (3 lines)",
		"  {{delete_two_up}} = delete current line and 2 lines above (3 lines)",
		"",
		"Navigate to the green target and use the indicated key sequence.",
	},
	hint_template = {
		"[{{delete_down}}] Delete 2 lines down  [{{delete_up}}] Delete 2 lines up  [{{delete_two_down}}] Delete 3 down  [{{delete_two_up}}] Delete 3 up",
	},
	template_tokens = {
		delete_down = "dj",
		delete_up = "dk",
		delete_two_down = "d2j",
		delete_two_up = "d2k",
	},
})
-- Pre-defined challenge pool with larger snippets to accommodate multi-line deletions.
-- Each challenge removes multiple lines from the snippet.
local CHALLENGES = {
	-- Challenge 1: dj — delete 2 lines (comment block)
	{
		snippet_lines = {
			"function processData(input) {",
			"  // TODO: remove this debug line",
			"  // console.log('debug:', input);",
			"  const result = transform(input);",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function processData(input) {",
			"  const result = transform(input);",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 5, col = 0 },
		key = "dj",
	},

	-- Challenge 2: dk — delete 2 lines (empty line + comment)
	{
		snippet_lines = {
			"function validateInput(data) {",
			"  if (!data) return false;",
			"",
			"  // Unused validation check",
			"  const isValid = data.length > 0;",
			"  return isValid;",
			"}",
		},
		expected_lines = {
			"function validateInput(data) {",
			"  if (!data) return false;",
			"  const isValid = data.length > 0;",
			"  return isValid;",
			"}",
		},
		target = { row = 3, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "dk",
	},

	-- Challenge 3: dj — delete 2 lines (variable declarations)
	{
		snippet_lines = {
			"function calculate(x, y) {",
			"  const temp1 = x * 2;",
			"  const temp2 = y * 2;",
			"  const result = x + y;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function calculate(x, y) {",
			"  const result = x + y;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 5, col = 0 },
		key = "dj",
	},

	-- Challenge 4: dk — delete 2 lines (debug statements)
	{
		snippet_lines = {
			"function fetchUser(id) {",
			"  const url = buildUrl(id);",
			"  console.log('fetching:', url);",
			"  console.log('timestamp:', Date.now());",
			"  return fetch(url);",
			"}",
		},
		expected_lines = {
			"function fetchUser(id) {",
			"  const url = buildUrl(id);",
			"  return fetch(url);",
			"}",
		},
		target = { row = 3, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "dk",
	},

	-- Challenge 5: d2j — delete 3 lines (try-catch block)
	{
		snippet_lines = {
			"function parseData(json) {",
			"  try {",
			"    return JSON.parse(json);",
			"  } catch (e) {",
			"    console.error(e);",
			"  }",
			"  return JSON.parse(json);",
			"}",
		},
		expected_lines = {
			"function parseData(json) {",
			"    console.error(e);",
			"  }",
			"  return JSON.parse(json);",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 7, col = 0 },
		key = "d2j",
	},

	-- Challenge 6: d2k — delete 3 lines (import statements)
	{
		snippet_lines = {
			"import { useState } from 'react';",
			"import { useEffect } from 'react';",
			"import { useCallback } from 'react';",
			"import { api } from './api';",
			"",
			"function App() {",
			"  return <div>Hello</div>;",
			"}",
		},
		expected_lines = {
			"import { api } from './api';",
			"",
			"function App() {",
			"  return <div>Hello</div>;",
			"}",
		},
		target = { row = 2, col = 0 },
		start_pos = { row = 7, col = 0 },
		key = "d2k",
	},

	-- Challenge 7: dj — delete 2 lines (console logs)
	{
		snippet_lines = {
			"function initialize(config) {",
			"  console.log('Init start');",
			"  console.log('Config:', config);",
			"  setupComponents(config);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function initialize(config) {",
			"  setupComponents(config);",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 5, col = 0 },
		key = "dj",
	},

	-- Challenge 8: dk — delete 2 lines (old code)
	{
		snippet_lines = {
			"function processOrder(order) {",
			"  const items = order.items;",
			"  // const tax = calculateTax(items);",
			"  // const shipping = calculateShipping(items);",
			"  const total = calculateTotal(items);",
			"  return total;",
			"}",
		},
		expected_lines = {
			"function processOrder(order) {",
			"  const items = order.items;",
			"  const total = calculateTotal(items);",
			"  return total;",
			"}",
		},
		target = { row = 3, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "dk",
	},

	-- Challenge 9: d2j — delete 3 lines (error handling)
	{
		snippet_lines = {
			"function loadData(source) {",
			"  if (!source) {",
			"    console.error('No source');",
			"    return null;",
			"  }",
			"  return fetchFromSource(source);",
			"}",
		},
		expected_lines = {
			"function loadData(source) {",
			"  }",
			"  return fetchFromSource(source);",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 6, col = 0 },
		key = "d2j",
	},

	-- Challenge 10: d2k — delete 3 lines (comment block)
	{
		snippet_lines = {
			"function renderComponent(props) {",
			"  // Step 1: Validate props",
			"  // Step 2: Build markup",
			"  // Step 3: Attach events",
			"  const element = createElement(props);",
			"  return element;",
			"}",
		},
		expected_lines = {
			"function renderComponent(props) {",
			"  const element = createElement(props);",
			"  return element;",
			"}",
		},
		target = { row = 3, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "d2k",
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

	-- Compute highlight_rows based on key
	local highlight_rows = {}
	if c.key == "dj" then
		highlight_rows = { c.target.row, c.target.row + 1 }
	elseif c.key == "dk" then
		highlight_rows = { c.target.row - 1, c.target.row }
	elseif c.key == "d2j" then
		highlight_rows = { c.target.row, c.target.row + 1, c.target.row + 2 }
	elseif c.key == "d2k" then
		highlight_rows = { c.target.row - 2, c.target.row - 1, c.target.row }
	end

	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		goal_text = "Delete the highlighted lines",
		highlight_rows = highlight_rows,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
