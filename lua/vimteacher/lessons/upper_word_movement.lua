-- vimteacher/lessons/upper_word_movement.lua
-- Eighth lesson: Moving by WORDs with W, E, B

local snippets = require("vimteacher.snippets")
local optimal = require("vimteacher.optimal")

local M = {}

M.title = "Moving by WORDs: W, E, B"

M.description = {
	"Uppercase WORD motions treat anything between spaces as one WORD.",
	"",
	"  W = next WORD    E = end of WORD    B = previous WORD",
	"",
	"A WORD is any group of non-space characters. Unlike w/e/b,",
	"symbols don't create boundaries:",
	"",
	"  user.getName()   →  1 WORD  (w/e/b sees 6 words)",
	"  arr[idx] += 1    →  3 WORDs (w/e/b sees 7 words)",
	"",
	"Move your cursor to the green highlighted target below.",
}

M.hint_lines = {
	"[W] Next WORD  [E] End of WORD  [B] Back a WORD — Move to the green target",
}

M.dwell_time = 200 -- ms; same as word_movement

-- Module-level snippet storage so compute_optimal can access the current snippet
local current_snippet = nil

--- Find all WORD-start positions in a snippet.
--- A WORD is any sequence of non-whitespace characters.
--- A WORD start is the first non-space character after whitespace or at line start.
--- @param lines string[] Snippet lines
--- @return table[] Ordered list of {row, col} (0-indexed)
local function find_WORD_starts(lines)
	local positions = {}
	for row_idx, line in ipairs(lines) do
		if #line > 0 then
			local col = 1
			while col <= #line do
				local char = line:sub(col, col)
				if char:match("%s") then
					col = col + 1
				else
					-- Start of a WORD
					positions[#positions + 1] = { row = row_idx - 1, col = col - 1 }
					-- Skip to end of WORD (next space or end of line)
					while col <= #line and not line:sub(col, col):match("%s") do
						col = col + 1
					end
				end
			end
		end
	end
	return positions
end

-- Expose for testing
M._find_WORD_starts = find_WORD_starts

--- Find the index of a position in a WORD_starts list.
--- @param word_starts table[] Ordered list of {row, col}
--- @param pos table {row, col}
--- @return number|nil Index (1-based) or nil if not found
local function find_position_index(word_starts, pos)
	for i, ws in ipairs(word_starts) do
		if ws.row == pos.row and ws.col == pos.col then
			return i
		end
	end
	return nil
end

--- Compute the minimum (optimal) moves between two positions.
--- For WORD movement, this is the number of W or B presses needed.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if not current_snippet then
		return optimal.manhattan(start_pos, target)
	end

	local word_starts = find_WORD_starts(current_snippet)
	local start_idx = find_position_index(word_starts, start_pos)
	local target_idx = find_position_index(word_starts, target)

	if start_idx and target_idx then
		return math.abs(target_idx - start_idx)
	end

	return optimal.nav_cost(current_snippet, start_pos, target, { "h", "j", "k", "l", "W", "B", "E", "0", "^", "$" })
end

--- Generate a new challenge: random snippet + random WORD-start target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
	local snippet = snippets.get_random()
	current_snippet = snippet

	local word_starts = find_WORD_starts(snippet)

	-- Safety: need at least 2 WORD starts for a meaningful challenge
	if #word_starts < 2 then
		return M.generate_challenge(buf, ns_id)
	end

	-- Pick a random target
	local target_idx = math.random(1, #word_starts)
	local target = word_starts[target_idx]

	-- Pick a starting position at least 3 WORD-hops from target
	local candidates = {}
	for i, ws in ipairs(word_starts) do
		local dist = math.abs(i - target_idx)
		if dist >= 3 then
			candidates[#candidates + 1] = { row = ws.row, col = ws.col, dist = dist }
		end
	end

	local start_pos
	if #candidates == 0 then
		-- Fallback: pick the farthest WORD start from target
		local best_dist = 0
		for i, ws in ipairs(word_starts) do
			local dist = math.abs(i - target_idx)
			if dist > best_dist then
				best_dist = dist
				start_pos = { row = ws.row, col = ws.col }
			end
		end
	else
		-- Prefer positions around 5 WORD-hops away
		table.sort(candidates, function(a, b)
			return math.abs(a.dist - 5) < math.abs(b.dist - 5)
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
