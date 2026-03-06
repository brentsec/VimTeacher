-- vimteacher/lessons/line_ends.lua
-- Ninth lesson: Moving to line boundaries with 0, $, _

local base = require("vimteacher.lessons.base")
local snippets = require("vimteacher.snippets")

local M = base.define({
	title_template = "Line Boundaries: {{line_start}}, {{line_end}}, {{first_nonblank}}",
	description_template = {
		"Jump to important positions on the current line.",
		"",
		"  {{line_start}} = beginning of line (column 0)",
		"  {{line_end}} = end of line (last character)",
		"  {{first_nonblank}} = first non-blank character",
		"",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[{{line_start}}] Line start  [{{line_end}}] Line end  [{{first_nonblank}}] First non-blank — Move to the green target",
	},
	dwell_time = 50,
	template_tokens = {
		line_start = "0",
		line_end = "$",
		first_nonblank = "_",
	},
})
--- Find all line boundary positions in a snippet.
--- Returns one entry per non-empty line with col_0, col_end, col_first_nonblank.
--- @param lines string[] Snippet lines
--- @return table[] List of {row, col_0, col_end, col_first_nonblank}
local function find_line_boundaries(lines)
	local boundaries = {}
	for row_idx, line in ipairs(lines) do
		if #line > 0 then
			local first_non_blank = line:find("%S")
			boundaries[#boundaries + 1] = {
				row = row_idx - 1,
				col_0 = 0,
				col_end = #line - 1,
				col_first_nonblank = first_non_blank and (first_non_blank - 1) or 0,
			}
		end
	end
	return boundaries
end

-- Expose for testing
M._find_line_boundaries = find_line_boundaries

--- Compute the minimum (optimal) moves between two positions.
--- For line-end movements: same pos = 0, same row = 1, different row = 2.
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

--- Generate a new challenge: random snippet + boundary target + start position.
--- @param buf number Buffer handle (unused)
--- @param ns_id number Namespace ID (unused)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
	local snippet = snippets.get_random()
	local boundaries = find_line_boundaries(snippet)

	-- Safety: need at least 2 non-empty lines for meaningful start/target separation
	if #boundaries < 2 then
		return M.generate_challenge(buf, ns_id)
	end

	-- Pick a random line
	local bound_idx = math.random(1, #boundaries)
	local bound = boundaries[bound_idx]

	-- Pick a random boundary type
	local boundary_types = { "0", "$", "_" }
	local btype = boundary_types[math.random(1, #boundary_types)]

	local target_col
	if btype == "0" then
		target_col = bound.col_0
	elseif btype == "$" then
		target_col = bound.col_end
	else -- "_"
		target_col = bound.col_first_nonblank
	end

	local target = { row = bound.row, col = target_col }

	-- Pick start position on a different line
	local start_candidates = {}
	for i, b in ipairs(boundaries) do
		if i ~= bound_idx then
			-- Start at a non-trivial column (middle of line or first non-blank)
			local start_col = b.col_first_nonblank
			if b.col_end > 2 then
				start_col = math.random(b.col_first_nonblank, b.col_end)
			end
			start_candidates[#start_candidates + 1] = { row = b.row, col = start_col }
		end
	end

	local start_pos
	if #start_candidates == 0 then
		-- Fallback: same line, different column
		start_pos = { row = bound.row, col = bound.col_first_nonblank }
		if start_pos.col == target_col and bound.col_end > 0 then
			start_pos.col = bound.col_end
		end
	else
		start_pos = start_candidates[math.random(1, #start_candidates)]
	end

	return {
		snippet_lines = snippet,
		target = target,
		start_pos = start_pos,
	}
end

return M
