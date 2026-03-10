-- vimteacher/lessons/word_movement.lua
-- Second lesson: Moving by words with w, e, b

local base = require("vimteacher.lessons.base")
local snippets = require("vimteacher.snippets")
local optimal = require("vimteacher.optimal")
local text_class = require("vimteacher.text_class")

local M = base.define({
	title_template = "Moving by Words: {{next_word}}, {{end_word}}, {{back_word}}",
	adaptive_keys = { "w", "e", "b" },
	description_template = {
		"Jump by whole words instead of character by character.",
		"",
		"  {{next_word}} = next word    {{end_word}} = end of word    {{back_word}} = previous word",
		"",
		"A word is letters, digits, and underscores grouped together.",
		"Whitespace between them creates separate words:",
		"",
		"  count one test1234 my_var",
		"  ──1── ─2─ ───3──── ──4───",
		"",
		"Symbols create word boundaries too, even with no spaces:",
		"  user.name   →  user | . | name     (3 words)",
		"  get_data()  →  get_data | ()       (2 words)",
		"  x += 1      →  x | += | 1         (3 words)",
		"",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[{{next_word}}] Next word  [{{end_word}}] End of word  [{{back_word}}] Back a word — Move to the green target",
	},
	goal_text_template = "Move to target using {{next_word}}/{{end_word}}/{{back_word}}",
	dwell_time = 200,
	template_tokens = {
		next_word = "w",
		end_word = "e",
		back_word = "b",
	},
})
-- Module-level snippet storage so compute_optimal can access the current snippet
local current_snippet = nil

--- Find all word-start positions in a snippet.
--- A word start is the first character of a word-class or punct-class sequence,
--- following whitespace or a different character class.
--- @param lines string[] Snippet lines
--- @return table[] Ordered list of {row, col} (0-indexed)
local function find_word_starts(lines)
	local positions = {}
	for row_idx, line in ipairs(lines) do
		if #line > 0 then
			local col = 1
			while col <= #line do
				local char = line:sub(col, col)
				local cls = text_class.char_class(char)
				if cls == "space" then
					col = col + 1
				else
					-- This is the start of a word (word-class or punct-class sequence)
					positions[#positions + 1] = { row = row_idx - 1, col = col - 1 }
					-- Skip to the end of this word (same class sequence)
					col = col + 1
					while col <= #line do
						local c = line:sub(col, col)
						local c_cls = text_class.char_class(c)
						if c_cls ~= cls then
							break
						end
						col = col + 1
					end
				end
			end
		end
	end
	return positions
end

-- Expose for testing
M._find_word_starts = find_word_starts

--- Find the index of a position in a word_starts list.
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
--- For word movement, this is the number of w or b presses needed.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if not current_snippet then
		-- Fallback to Manhattan distance
		return optimal.manhattan(start_pos, target)
	end

	local word_starts = find_word_starts(current_snippet)
	local start_idx = find_position_index(word_starts, start_pos)
	local target_idx = find_position_index(word_starts, target)

	if start_idx and target_idx then
		return math.abs(target_idx - start_idx)
	end

	-- Fallback
	return optimal.nav_cost(current_snippet, start_pos, target, { "h", "j", "k", "l", "w", "b", "e", "0", "^", "$" })
end

--- Generate a new challenge: random snippet + random word-start target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge()
	local snippet = snippets.get_random()
	current_snippet = snippet

	local word_starts = find_word_starts(snippet)

	-- Safety: need at least 2 word starts for a meaningful challenge
	if #word_starts < 2 then
		return M.generate_challenge()
	end

	-- Pick a random target
	local target_idx = math.random(1, #word_starts)
	local target = word_starts[target_idx]

	-- Pick a starting position at least 3 word-hops from target
	local candidates = {}
	for i, ws in ipairs(word_starts) do
		local dist = math.abs(i - target_idx)
		if dist >= 3 then
			candidates[#candidates + 1] = { row = ws.row, col = ws.col, dist = dist }
		end
	end

	local start_pos
	if #candidates == 0 then
		-- Fallback: pick the farthest word start from target
		local best_dist = 0
		for i, ws in ipairs(word_starts) do
			local dist = math.abs(i - target_idx)
			if dist > best_dist then
				best_dist = dist
				start_pos = { row = ws.row, col = ws.col }
			end
		end
	else
		-- Prefer positions around 5 word-hops away
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
