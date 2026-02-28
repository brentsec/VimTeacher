-- vimteacher/lessons/basic_movement.lua
-- First lesson: Basic cursor movement with h, j, k, l

local snippets = require("vimteacher.snippets")

local M = {}

M.title = "Basic Movement: h, j, k, l"

M.description = {
	"Vim uses h, j, k, l for cursor movement instead of arrow keys.",
	"",
	"  h = left    j = down    k = up    l = right",
	"",
	"Move your cursor to the green highlighted target below.",
}

M.hint_lines = {
	"[h] Left  [j] Down  [k] Up  [l] Right — Move to the green target",
}

--- Compute the minimum (optimal) moves between two positions.
--- For basic movement (h/j/k/l), this is the Manhattan distance.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	return math.abs(start_pos.row - target.row) + math.abs(start_pos.col - target.col)
end

--- Generate a new challenge: random snippet + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
	local snippet = snippets.get_random()

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
		return M.generate_challenge(buf, ns_id)
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

return M
