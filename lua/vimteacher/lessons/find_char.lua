-- vimteacher/lessons/find_char.lua
-- Tenth lesson: Finding characters with f, F, ;

local base = require("vimteacher.lessons.base")
local challenge_utils = require("vimteacher.lessons.challenge_utils")
local snippets = require("vimteacher.snippets")

local M = base.define({
	title_template = "Find Character: {{forward}}, {{backward}}, {{repeat_find}}",
	description_template = {
		"Jump to a specific character on the current line.",
		"",
		"  {{forward}}{char} = find FORWARD to {char} (lands ON the character)",
		"  {{backward}}{char} = find BACKWARD to {char}",
		"  {{repeat_find}}       = repeat the last {{forward}} or {{backward}} motion",
		"",
		"These motions only work within the current line.",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[{{forward}}{c}] Find forward  [{{backward}}{c}] Find backward  [{{repeat_find}}] Repeat last find",
	},
	dwell_time = 50,
	template_tokens = {
		forward = "f",
		backward = "F",
		repeat_find = ";",
	},
})
--- Compute the minimum (optimal) moves between two positions.
--- For find-char: same pos = 0, same row = 1 (single f/F), different row = 2.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end
	if start_pos.row == target.row then
		return 1
	end
	return 2
end

--- Generate a new challenge: random snippet + character target on the same line.
--- @param buf number Buffer handle (unused)
--- @param ns_id number Namespace ID (unused)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge()
	return challenge_utils.generate_with_retries("find_char", function()
		local snippet = snippets.get_random()

		-- Build list of non-whitespace positions for each line
		local line_positions = {} -- line_positions[row_idx] = list of {col, char}
		for row_idx, line in ipairs(snippet) do
			local positions = {}
			for col = 1, #line do
				local char = line:sub(col, col)
				if char ~= " " and char ~= "\t" then
					positions[#positions + 1] = { col = col - 1, char = char }
				end
			end
			if #positions >= 3 then -- need at least 3 chars for meaningful f/F
				line_positions[#line_positions + 1] = {
					row = row_idx - 1,
					positions = positions,
				}
			end
		end

		-- Safety: need at least 1 line with enough chars
		if #line_positions == 0 then
			return nil
		end

		-- Pick a random line
		local line_entry = line_positions[math.random(1, #line_positions)]
		local positions = line_entry.positions

		-- Pick target: avoid first and last position for more interesting f/F usage
		local target_idx
		if #positions > 2 then
			target_idx = math.random(2, #positions - 1)
		else
			target_idx = math.random(1, #positions)
		end
		local target = { row = line_entry.row, col = positions[target_idx].col }

		-- Pick start position: on the same line, different column, at least 2 positions away
		local start_candidates = {}
		for i, pos in ipairs(positions) do
			local dist = math.abs(i - target_idx)
			if dist >= 2 then
				start_candidates[#start_candidates + 1] = { col = pos.col, dist = dist }
			end
		end

		local start_pos
		if #start_candidates > 0 then
			local chosen = start_candidates[math.random(1, #start_candidates)]
			start_pos = { row = line_entry.row, col = chosen.col }
		else
			-- Fallback: pick first or last position on the line
			if target_idx > 1 then
				start_pos = { row = line_entry.row, col = positions[1].col }
			else
				start_pos = { row = line_entry.row, col = positions[#positions].col }
			end
		end

		return {
			snippet_lines = snippet,
			target = target,
			start_pos = start_pos,
		}
	end)
end

return M
