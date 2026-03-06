-- vimteacher/lessons/repeat_power.lua
-- Repeat command lesson: perform a delete, then repeat it with dot.

local base = require("vimteacher.lessons.base")
local challenge_utils = require("vimteacher.lessons.challenge_utils")
local pool = require("vimteacher.lessons.pool")
local optimal = require("vimteacher.optimal")

local M = base.define({
	title_template = "Repeat Power: {{repeat_cmd}} and counts",
	type = "insert",
	allowed_keys = {},
	allowed_modify_keys = { "x", "." },
	allowed_nav_keys = {
		"h",
		"j",
		"k",
		"l",
		"w",
		"b",
		"e",
		"0",
		"1",
		"2",
		"3",
		"4",
		"5",
		"6",
		"7",
		"8",
		"9",
	},
	challenges_required = 10,
	template_tokens = {
		x = "x",
		repeat_cmd = ".",
	},
	description_template = {
		"The dot command repeats your last change.",
		"That means you can fix one spot manually, then apply the same edit again",
		"without retyping the full command sequence each time.",
		"Each challenge is two-step:",
		"1) do the first delete on the highlighted target ({{x}} or 3{{x}}),",
		"2) move to the new target and press {{repeat_cmd}} to repeat it.",
	},
	hint_template = {
		"[{{x}}] Delete char  [3{{x}}] Delete 3 chars  [{{repeat_cmd}}] Repeat last change",
	},
})

--- @param line string
--- @param col number 0-indexed
--- @param n number
--- @return string
local function apply_x_n(line, col, n)
	local out = line
	for _ = 1, n do
		if col >= #out then
			break
		end
		out = out:sub(1, col) .. out:sub(col + 2)
	end
	return out
end

--- @param def table
--- @return table
local function build_challenge(def)
	local snippet = vim.deepcopy(def.snippet_lines)
	local count = def.count or 1
	local key1 = (count == 1) and "x" or (tostring(count) .. "x")

	local row1 = def.phase1.row
	local line1 = snippet[row1 + 1] or ""
	local p1_start = challenge_utils.find_nth(line1, def.phase1.find, def.phase1.occurrence or 1)
	assert(p1_start, "repeat_power phase1 find failed: " .. tostring(def.phase1.find))
	local p1_col = (p1_start - 1) + (def.phase1.offset or 0)

	local after1 = vim.deepcopy(snippet)
	after1[row1 + 1] = apply_x_n(after1[row1 + 1], p1_col, count)

	local row2 = def.phase2.row
	local line2 = after1[row2 + 1] or ""
	local p2_start = challenge_utils.find_nth(line2, def.phase2.find, def.phase2.occurrence or 1)
	assert(p2_start, "repeat_power phase2 find failed: " .. tostring(def.phase2.find))
	local p2_col = (p2_start - 1) + (def.phase2.offset or 0)

	local after2 = vim.deepcopy(after1)
	after2[row2 + 1] = apply_x_n(after2[row2 + 1], p2_col, count)

	return {
		snippet_lines = snippet,
		expected_lines = vim.deepcopy(after2),
		target = { row = row1, col = p1_col },
		target_end_col = p1_col + count,
		start_pos = { row = def.start_pos.row, col = def.start_pos.col },
		key = key1,
		char = "x",
		phases = {
			{
				key = key1,
				char = "x",
				target = { row = row1, col = p1_col },
				target_end_col = p1_col + count,
				expected_lines = vim.deepcopy(after1),
			},
			{
				key = ".",
				char = key1,
				target = { row = row2, col = p2_col },
				target_end_col = p2_col + count,
				expected_lines = vim.deepcopy(after2),
			},
		},
	}
end

local CHALLENGE_DEFS = {
	{
		snippet_lines = {
			"function total() {",
			"  const sum = baad_value + goood_value;",
			"  return sum;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "baad_value", offset = 2 },
		phase2 = { row = 1, find = "goood_value", offset = 2 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function user() {",
			"  const first = joohn; const second = meery;",
			"  return first + second;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "joohn", offset = 2 },
		phase2 = { row = 1, find = "meery", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function path() {",
			"  const left = http:///api; const right = ws:///stream;",
			"  return left + right;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "http:///api", offset = 7 },
		phase2 = { row = 1, find = "ws:///stream", offset = 5 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function greet() {",
			'  const left = "heello"; const right = "goood";',
			"  return left + right;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "heello", offset = 2 },
		phase2 = { row = 1, find = "goood", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function calc() {",
			"  const total = 10000 + right_25000;",
			"  return total;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "10000", offset = 2 },
		phase2 = { row = 1, find = "25000", offset = 2 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function metrics() {",
			"  const cpu = 90000; const mem = 12000;",
			"  return cpu + mem;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "90000", offset = 2 },
		phase2 = { row = 1, find = "12000", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function cleanup() {",
			"  const left = value___ + right___;",
			"  return left + right;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "value___", offset = 5 },
		phase2 = { row = 1, find = "right___", offset = 5 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function flags() {",
			"  const a = truue; const b = faalse;",
			"  return a && b;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "truue", offset = 3 },
		phase2 = { row = 1, find = "faalse", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function ids() {",
			"  const one = itemm_id; const two = orderr_id;",
			"  return one + two;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "itemm_id", offset = 4 },
		phase2 = { row = 1, find = "orderr_id", offset = 5 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function labels() {",
			"  const a = alpha000; const b = beta000;",
			"  return a + b;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "alpha000", offset = 5 },
		phase2 = { row = 1, find = "beta000", offset = 4 },
		start_pos = { row = 0, col = 0 },
	},
}

local CHALLENGES = {}
for _, def in ipairs(CHALLENGE_DEFS) do
	CHALLENGES[#CHALLENGES + 1] = build_challenge(def)
end

local challenge_pool = pool.new(CHALLENGES, { track_current_snippet = false })

function M._compute_nav_optimal(lines, start_pos, target)
	return optimal.nav_cost(lines, start_pos, target)
end

--- Compute movement baseline across all phases using common Vim motions.
--- @param start_pos table {row=number, col=number}
--- @param target table {row=number, col=number}
--- @param challenge table|nil
--- @return number
function M.compute_optimal(start_pos, target, challenge)
	if challenge and challenge.phases and #challenge.phases > 0 then
		local total = 0
		local prev = { row = start_pos.row, col = start_pos.col }
		local lines = challenge.snippet_lines or {}
		for _, phase in ipairs(challenge.phases) do
			total = total + M._compute_nav_optimal(lines, prev, phase.target)
			if phase.expected_lines then
				lines = phase.expected_lines
			end
			prev = phase.target
		end
		return total
	end
	if challenge and challenge.snippet_lines then
		return M._compute_nav_optimal(challenge.snippet_lines, start_pos, target)
	end
	return optimal.manhattan(start_pos, target)
end

M.generate_challenge = challenge_pool.generate_challenge
M._get_challenges = challenge_pool.get_challenges

return M
