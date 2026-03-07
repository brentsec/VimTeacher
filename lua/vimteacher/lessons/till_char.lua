-- vimteacher/lessons/till_char.lua
-- Eleventh lesson: Till characters with t, T, ;

local base = require("vimteacher.lessons.base")
local snippets = require("vimteacher.snippets")

local M = base.define({
	title_template = "Till Character: {{forward}}, {{backward}}, {{repeat_till}}",
	description_template = {
		"Jump to just BEFORE a specific character on the current line.",
		"",
		"  {{forward}}{char} = move forward TILL {char} (one BEFORE it)",
		"  {{backward}}{char} = move backward TILL {char} (one AFTER it)",
		"  {{repeat_till}}       = repeat the last {{forward}} or {{backward}} motion",
		"",
		"Till motions are useful with operators like d or c:",
		"  dt) = delete up to (but not including) the closing paren",
		"",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[{{forward}}{c}] Till forward  [{{backward}}{c}] Till backward  [{{repeat_till}}] Repeat last till",
	},
	dwell_time = 50,
	template_tokens = {
		forward = "t",
		backward = "T",
		repeat_till = ";",
	},
})
--- Compute the minimum (optimal) moves between two positions.
--- For till-char: same pos = 0, same row = 1 (single t/T), different row = 2.
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

--- Generate a new challenge: random snippet + till-position target on the same line.
--- The target is where the cursor lands (one before/after the search char).
--- @param buf number Buffer handle (unused)
--- @param ns_id number Namespace ID (unused)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge()
	local snippet = snippets.get_random()

	-- Build list of valid till-targets per line
	-- For t: search_char at col C, target at col C-1 (must both be non-whitespace)
	-- For T: search_char at col C, target at col C+1 (must both be non-whitespace)
	local candidates = {} -- {row, col, search_col}

	for row_idx, line in ipairs(snippet) do
		if #line >= 3 then
			for col = 1, #line do
				local char = line:sub(col, col)
				if char ~= " " and char ~= "\t" then
					-- Check t-candidate: target at col-1 (0-indexed: col-2)
					if col > 1 then
						local prev = line:sub(col - 1, col - 1)
						if prev ~= " " and prev ~= "\t" then
							candidates[#candidates + 1] = {
								row = row_idx - 1,
								col = col - 2, -- 0-indexed target (one before search char)
								search_col = col - 1, -- 0-indexed search char position
							}
						end
					end
					-- Check T-candidate: target at col+1 (0-indexed: col)
					if col < #line then
						local next_char = line:sub(col + 1, col + 1)
						if next_char ~= " " and next_char ~= "\t" then
							candidates[#candidates + 1] = {
								row = row_idx - 1,
								col = col, -- 0-indexed target (one after search char)
								search_col = col - 1, -- 0-indexed search char position
							}
						end
					end
				end
			end
		end
	end

	-- Safety: need candidates
	if #candidates == 0 then
		return M.generate_challenge()
	end

	-- Pick a random candidate
	local chosen = candidates[math.random(1, #candidates)]
	local target = { row = chosen.row, col = chosen.col }

	-- Pick start position: same line, different column, at least 2 cols away
	local line = snippet[chosen.row + 1]
	local start_candidates = {}
	for col = 1, #line do
		local char = line:sub(col, col)
		if char ~= " " and char ~= "\t" then
			local dist = math.abs((col - 1) - chosen.col)
			if dist >= 3 then
				start_candidates[#start_candidates + 1] = { col = col - 1, dist = dist }
			end
		end
	end

	local start_pos
	if #start_candidates > 0 then
		-- Prefer moderate distance
		table.sort(start_candidates, function(a, b)
			return math.abs(a.dist - 8) < math.abs(b.dist - 8)
		end)
		local top_n = math.min(5, #start_candidates)
		local pick = start_candidates[math.random(1, top_n)]
		start_pos = { row = chosen.row, col = pick.col }
	else
		-- Fallback: find any non-whitespace char on the line at different col
		for col = 1, #line do
			local char = line:sub(col, col)
			if char ~= " " and char ~= "\t" and (col - 1) ~= chosen.col then
				start_pos = { row = chosen.row, col = col - 1 }
				break
			end
		end
		if not start_pos then
			-- Extreme fallback: different line
			for row_idx, l in ipairs(snippet) do
				if row_idx - 1 ~= chosen.row and #l > 0 then
					local first = l:find("%S")
					if first then
						start_pos = { row = row_idx - 1, col = first - 1 }
						break
					end
				end
			end
		end
	end

	-- Final fallback
	if not start_pos then
		start_pos = { row = 0, col = 0 }
	end

	return {
		snippet_lines = snippet,
		target = target,
		start_pos = start_pos,
	}
end

return M
