-- vimteacher/lessons/copy_paste_lines.lua
-- Lesson 11: Copy and paste lines with yy, p, P

local M = {}

M.title = "Copy & Paste: yy, p, P"
M.type = "insert"
M.allowed_keys = {}
M.allowed_modify_keys = { "p", "P" }
M.challenges_required = 10

M.description = {
	"Copy and paste entire lines:",
	"",
	"  yy = yank (copy) the current line",
	"  p  = paste below the current line",
	"  P  = paste above the current line",
	"",
	"Navigate to the green target line, yank it with yy, then paste where needed.",
}

M.hint_lines = {
	"[yy] Yank line  [p] Paste below  [P] Paste above  [hjkl] Navigate",
}

function M.get_title(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local yy = key_display["yy"] or "yy"
	local p = key_display["p"] or "p"
	local P = key_display["P"] or "P"
	return string.format("Copy & Paste: %s, %s, %s", yy, p, P)
end

function M.get_description(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local yy = key_display["yy"] or "yy"
	local p = key_display["p"] or "p"
	local P = key_display["P"] or "P"
	return {
		"Copy and paste entire lines:",
		"",
		string.format("  %s = yank (copy) the current line", yy),
		string.format("  %s  = paste below the current line", p),
		string.format("  %s  = paste above the current line", P),
		"",
		"Navigate to the green target line, yank it with yy, then paste where needed.",
	}
end

function M.get_hint_lines(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local yy = key_display["yy"] or "yy"
	local p = key_display["p"] or "p"
	local P = key_display["P"] or "P"
	return {
		string.format("[%s] Yank line  [%s] Paste below  [%s] Paste above  [hjkl] Navigate", yy, p, P),
	}
end

-- Pre-defined challenge pool.
-- Each challenge has:
-- - snippet_lines: starting code (N lines)
-- - expected_lines: after yank + paste (N+1 lines)
-- - target: {row = yank_row, col = 0} (line to yank)
-- - start_pos: cursor starting position
-- - key: "p" or "P" (paste operation)
-- - yank_row: 0-indexed row to yank
-- - paste_after_row: 0-indexed row where paste occurs relative to
local CHALLENGES = {
	-- Challenge 1: p — duplicate console.log line below
	{
		snippet_lines = {
			"function debug(msg) {",
			"  console.log(msg);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function debug(msg) {",
			"  console.log(msg);",
			"  console.log(msg);",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 3, col = 0 },
		key = "p",
		yank_row = 1,
		paste_after_row = 1,
	},

	-- Challenge 2: P — duplicate function signature above return
	{
		snippet_lines = {
			"function calculate(x, y) {",
			"  const result = x + y;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function calculate(x, y) {",
			"  const result = x + y;",
			"  const result = x + y;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "P",
		yank_row = 1,
		paste_after_row = 2,
	},

	-- Challenge 3: p — duplicate const declaration below
	{
		snippet_lines = {
			"function setup() {",
			"  const port = 3000;",
			"  const host = 'localhost';",
			"  return { port, host };",
			"}",
		},
		expected_lines = {
			"function setup() {",
			"  const port = 3000;",
			"  const port = 3000;",
			"  const host = 'localhost';",
			"  return { port, host };",
			"}",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 4, col = 0 },
		key = "p",
		yank_row = 1,
		paste_after_row = 1,
	},

	-- Challenge 4: P — duplicate if-check above else
	{
		snippet_lines = {
			"function validate(input) {",
			"  if (input.length > 0) {",
			"    return true;",
			"  }",
			"  return false;",
			"}",
		},
		expected_lines = {
			"function validate(input) {",
			"  if (input.length > 0) {",
			"    return true;",
			"  }",
			"  if (input.length > 0) {",
			"  return false;",
			"}",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 5, col = 0 },
		key = "P",
		yank_row = 1,
		paste_after_row = 4,
	},

	-- Challenge 5: p — duplicate import statement below
	{
		snippet_lines = {
			"import React from 'react';",
			"import useState from 'react';",
			"",
			"function App() {",
			"  return <div>Hello</div>;",
			"}",
		},
		expected_lines = {
			"import React from 'react';",
			"import useState from 'react';",
			"import useState from 'react';",
			"",
			"function App() {",
			"  return <div>Hello</div>;",
			"}",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 3, col = 0 },
		key = "p",
		yank_row = 1,
		paste_after_row = 1,
	},

	-- Challenge 6: P — duplicate closing brace above function end
	{
		snippet_lines = {
			"function process(data) {",
			"  if (data) {",
			"    return data.value;",
			"  }",
			"}",
		},
		expected_lines = {
			"function process(data) {",
			"  if (data) {",
			"    return data.value;",
			"  }",
			"  }",
			"}",
		},
		target = { row = 3, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "P",
		yank_row = 3,
		paste_after_row = 4,
	},

	-- Challenge 7: p — duplicate array element below
	{
		snippet_lines = {
			"const colors = [",
			"  'red',",
			"  'blue',",
			"  'green',",
			"];",
		},
		expected_lines = {
			"const colors = [",
			"  'red',",
			"  'blue',",
			"  'blue',",
			"  'green',",
			"];",
		},
		target = { row = 2, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "p",
		yank_row = 2,
		paste_after_row = 2,
	},

	-- Challenge 8: P — duplicate comment above function
	{
		snippet_lines = {
			"// Helper function",
			"function helper(x) {",
			"  return x * 2;",
			"}",
		},
		expected_lines = {
			"// Helper function",
			"// Helper function",
			"function helper(x) {",
			"  return x * 2;",
			"}",
		},
		target = { row = 0, col = 0 },
		start_pos = { row = 3, col = 0 },
		key = "P",
		yank_row = 0,
		paste_after_row = 1,
	},

	-- Challenge 9: p — duplicate object property below
	{
		snippet_lines = {
			"const config = {",
			"  debug: true,",
			"  verbose: false,",
			"};",
		},
		expected_lines = {
			"const config = {",
			"  debug: true,",
			"  debug: true,",
			"  verbose: false,",
			"};",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 3, col = 0 },
		key = "p",
		yank_row = 1,
		paste_after_row = 1,
	},

	-- Challenge 10: P — duplicate return statement above closing brace
	{
		snippet_lines = {
			"function getName() {",
			"  const name = 'Alice';",
			"  return name;",
			"}",
		},
		expected_lines = {
			"function getName() {",
			"  const name = 'Alice';",
			"  return name;",
			"  return name;",
			"}",
		},
		target = { row = 2, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "P",
		yank_row = 2,
		paste_after_row = 3,
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves to complete the challenge.
--- User must navigate to yank_row (target), yank with yy, then paste with p/P.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	-- Navigation distance (row difference only, col doesn't matter for yy)
	local nav_distance = math.abs(start_pos.row - target.row)
	-- yy + p/P = 2 additional moves
	return nav_distance + 2
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, yank_row, paste_after_row}
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

	-- Compute where the marker should appear (actual insertion point).
	-- For p: paste goes below cursor row = after paste_after_row (correct as-is).
	-- For P: paste goes above cursor row = after paste_after_row - 1.
	local paste_marker_after_row = c.paste_after_row
	if c.key == "P" then
		paste_marker_after_row = c.paste_after_row - 1
	end

	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		goal_text = "Yank the highlighted line with yy, then paste it at the ▸ marker",
		highlight_rows = { c.target.row },
		yank_row = c.yank_row,
		paste_after_row = c.paste_after_row,
		paste_marker_after_row = paste_marker_after_row,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
