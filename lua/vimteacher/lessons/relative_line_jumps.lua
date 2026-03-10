-- vimteacher/lessons/relative_line_jumps.lua
-- Lesson: Relative line jumps with count + j/k (e.g., 5j, 3k)

local base = require("vimteacher.lessons.base")
local challenge_utils = require("vimteacher.lessons.challenge_utils")
local snippets = require("vimteacher.snippets")

local M = base.define({
	title_template = "Line Jumps: 5{{down}}, 3{{up}}",
	dwell_time = 50,
	description_template = {
		"Use count + j/k to jump multiple lines at once.",
		"",
		"  5{{down}} = jump 5 lines down",
		"  3{{up}} = jump 3 lines up",
		"",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[count+{{down}}] Jump down  [count+{{up}}] Jump up  [h/l] Adjust column — Move to the green target",
	},
	template_tokens = {
		down = "j",
		up = "k",
	},
})
--- Compute the minimum (optimal) moves between two positions.
--- For relative line jumps: row difference = 1 move (counted jump), col difference = 1 move.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end

	local moves = 0

	-- If different row, that's 1 move (counted jump: e.g., 5j)
	if start_pos.row ~= target.row then
		moves = moves + 1
	end

	-- If different column, that's 1 move (h/l)
	if start_pos.col ~= target.col then
		moves = moves + 1
	end

	return moves
end

--- Generate a new challenge: random snippet + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge()
	return challenge_utils.generate_with_retries("relative_line_jumps", function()
		local snippet = snippets.get_random()
		if #snippet < 8 then
			return nil
		end

		local valid_positions = {}
		for row_idx, line in ipairs(snippet) do
			for col_idx = 1, #line do
				local char = line:sub(col_idx, col_idx)
				if char ~= " " and char ~= "\t" then
					valid_positions[#valid_positions + 1] = {
						row = row_idx - 1,
						col = col_idx - 1,
					}
				end
			end
		end

		if #valid_positions == 0 then
			return nil
		end

		local target = valid_positions[math.random(1, #valid_positions)]
		local candidates = {}
		for _, pos in ipairs(valid_positions) do
			local row_dist = math.abs(pos.row - target.row)
			if row_dist >= 3 then
				candidates[#candidates + 1] = {
					row = pos.row,
					col = pos.col,
					row_dist = row_dist,
				}
			end
		end

		local start_pos
		if #candidates == 0 then
			for i, line in ipairs(snippet) do
				if #line > 0 then
					start_pos = { row = i - 1, col = 0 }
					break
				end
			end
		else
			table.sort(candidates, function(a, b)
				return math.abs(a.row_dist - 6) < math.abs(b.row_dist - 6)
			end)
			local top_n = math.min(5, #candidates)
			local chosen = candidates[math.random(1, top_n)]
			start_pos = { row = chosen.row, col = chosen.col }
		end

		return {
			snippet_lines = snippet,
			target = target,
			start_pos = start_pos,
			goal_text = "Navigate to the green target",
		}
	end)
end

return M
