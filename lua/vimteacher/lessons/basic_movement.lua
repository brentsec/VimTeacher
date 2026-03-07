-- vimteacher/lessons/basic_movement.lua
-- First lesson: Basic cursor movement with h, j, k, l

local base = require("vimteacher.lessons.base")
local pool = require("vimteacher.lessons.pool")
local snippets = require("vimteacher.snippets")

local M = base.define({
	title_template = "Basic Movement: {{left}}, {{down}}, {{up}}, {{right}}",
	description_template = {
		"Vim uses {{left}}, {{down}}, {{up}}, {{right}} for cursor movement instead of arrow keys.",
		"",
		"  {{left}} = left    {{down}} = down    {{up}} = up    {{right}} = right",
		"",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[{{left}}] Left  [{{down}}] Down  [{{up}}] Up  [{{right}}] Right — Move to the green target",
	},
	goal_text_template = "Move to target using {{left}}/{{down}}/{{up}}/{{right}}",
	adaptive_keys = { "h", "j", "k", "l" },
	template_tokens = {
		left = "h",
		down = "j",
		up = "k",
		right = "l",
	},
})

local NAV_MOTIONS = { "h", "j", "k", "l", "0", "^", "$" }

local function build_challenge(snippet)
	snippet = snippet.snippet_lines

	-- Build list of all valid target positions (non-whitespace characters)
	local valid_positions = {}
	for row_idx, line in ipairs(snippet) do
		for col_idx = 1, #line do
			local char = line:sub(col_idx, col_idx)
			if char ~= " " and char ~= "\t" then
				valid_positions[#valid_positions + 1] = {
					row = row_idx - 1, -- 0-indexed
					col = col_idx - 1, -- 0-indexed
				}
			end
		end
	end

	-- Safety: if no valid positions (should never happen with our pool), retry
	if #valid_positions == 0 then
		return nil
	end

	-- Pick a random target
	local target = valid_positions[math.random(1, #valid_positions)]

	-- Pick a starting position at least 3 Manhattan distance from target
	local candidates = {}
	for _, pos in ipairs(valid_positions) do
		local dist = math.abs(pos.row - target.row) + math.abs(pos.col - target.col)
		if dist >= 3 then
			candidates[#candidates + 1] = { row = pos.row, col = pos.col, dist = dist }
		end
	end

	local start_pos
	if #candidates == 0 then
		-- Fallback: use first char of first non-empty line
		for i, line in ipairs(snippet) do
			if #line > 0 then
				start_pos = { row = i - 1, col = 0 }
				break
			end
		end
	else
		-- Prefer positions around 5-7 moves away (interesting but not tedious)
		table.sort(candidates, function(a, b)
			return math.abs(a.dist - 6) < math.abs(b.dist - 6)
		end)
		local top_n = math.min(5, #candidates)
		local chosen = candidates[math.random(1, top_n)]
		start_pos = { row = chosen.row, col = chosen.col }
	end

	return {
		snippet_lines = snippet,
		target = target,
		start_pos = start_pos,
	}
end

local snippet_challenges = {}
for _, snippet in ipairs(snippets.pool) do
	snippet_challenges[#snippet_challenges + 1] = { snippet_lines = snippet }
end

local challenge_pool = pool.new(snippet_challenges, {
	transform_challenge = build_challenge,
})

M.compute_optimal = challenge_pool.nav_compute_optimal(NAV_MOTIONS)
M.generate_challenge = challenge_pool.generate_challenge

return M
