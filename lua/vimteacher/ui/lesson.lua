-- vimteacher/ui/lesson.lua
-- Lesson screen rendering.

local common = require("vimteacher.ui.common")
local highlight = require("vimteacher.highlight")

local M = {}

local function add_part(parts, hl_regions, text, hl_group, byte_pos)
	if not text then
		return byte_pos
	end
	parts[#parts + 1] = text
	if hl_group then
		hl_regions[#hl_regions + 1] = { s = byte_pos, e = byte_pos + #text, g = hl_group }
	end
	return byte_pos + #text
end

--- Render the lesson layout with description, progress bar, and code snippet.
--- @param buf number Buffer handle
--- @param opts table Render options
---   opts.title: string
---   opts.description: string[]
---   opts.progress: number (current challenge, 1-based)
---   opts.max_progress: number (total challenges)
---   opts.snippet_lines: string[]
---   opts.hint_lines: string[]
---   opts.nav_hint_line: string|nil (custom bottom navigation hint during challenges)
--- @return table layout metadata
function M.render(buf, opts)
	local lines = {}

	lines[#lines + 1] = "  " .. opts.title
	lines[#lines + 1] = ""

	local desc_start = #lines
	for _, line in ipairs(opts.description) do
		lines[#lines + 1] = "  " .. line
	end
	local desc_end = #lines
	lines[#lines + 1] = ""

	local progress_line = nil
	if opts.progress then
		lines[#lines + 1] = "  " .. common.SEPARATOR
		progress_line = #lines
		local completed = opts.progress - 1
		local remaining = opts.max_progress - completed
		local bar = string.rep("#", completed) .. string.rep(".", remaining)
		lines[#lines + 1] = string.format("  Challenge %d/%d   [%s]", opts.progress, opts.max_progress, bar)
		lines[#lines + 1] = "  " .. common.SEPARATOR
	else
		lines[#lines + 1] = "  " .. common.SEPARATOR
	end

	local goal_row = nil
	local goal_hl_regions = {}
	if opts.goal then
		goal_row = #lines
		local parts = {}
		local byte_pos = 0

		byte_pos = add_part(parts, goal_hl_regions, "  ", nil, byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, "─── ", "VimTeacherSeparator", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, opts.goal.action, "VimTeacherGoalText", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, "  ", nil, byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, opts.goal.char, "VimTeacherInsertHint", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, "  ", nil, byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, opts.goal.preposition, "VimTeacherGoalText", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, " ── ", "VimTeacherSeparator", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, "press", "VimTeacherGoalText", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, "  ", nil, byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, opts.goal.key, "VimTeacherInsertHint", byte_pos)
		byte_pos = add_part(parts, goal_hl_regions, "  ", nil, byte_pos)

		local display_width = vim.api.nvim_strwidth(table.concat(parts, ""))
		local remaining = common.CONTENT_WIDTH + 2 - display_width
		if remaining > 0 then
			add_part(parts, goal_hl_regions, string.rep("─", remaining), "VimTeacherSeparator", byte_pos)
		end

		lines[#lines + 1] = table.concat(parts, "")
	end

	local goal_text_row = nil
	local goal_text_hl_regions = {}
	if not opts.goal and opts.goal_text then
		goal_text_row = #lines
		local parts = {}
		local byte_pos = 0

		byte_pos = add_part(parts, goal_text_hl_regions, "  ", nil, byte_pos)
		byte_pos = add_part(parts, goal_text_hl_regions, "─── ", "VimTeacherSeparator", byte_pos)
		byte_pos = add_part(parts, goal_text_hl_regions, opts.goal_text, "VimTeacherGoalText", byte_pos)
		byte_pos = add_part(parts, goal_text_hl_regions, " ", nil, byte_pos)

		local display_width = vim.api.nvim_strwidth(table.concat(parts, ""))
		local remaining = common.CONTENT_WIDTH + 2 - display_width
		if remaining > 0 then
			add_part(parts, goal_text_hl_regions, string.rep("─", remaining), "VimTeacherSeparator", byte_pos)
		end

		lines[#lines + 1] = table.concat(parts, "")
	end

	lines[#lines + 1] = ""

	local snippet_offset = #lines
	for _, line in ipairs(opts.snippet_lines) do
		lines[#lines + 1] = line
	end
	local snippet_end = #lines - 1

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. common.SEPARATOR
	local hint_start = #lines
	for _, line in ipairs(opts.hint_lines) do
		lines[#lines + 1] = "  " .. line
	end
	if opts.progress then
		lines[#lines + 1] = "  " .. (opts.nav_hint_line or "[q] Menu  [Q] Restart lesson")
	end
	local hint_end = #lines

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)

	highlight.apply_line_highlight(buf, 0, 1, "VimTeacherTitle")
	highlight.apply_line_highlight(buf, desc_start, desc_end, "VimTeacherHint")

	if progress_line then
		highlight.apply_line_highlight(buf, snippet_offset - 3, snippet_offset - 2, "VimTeacherSeparator")
		highlight.apply_line_highlight(buf, progress_line, progress_line + 1, "VimTeacherProgress")
		highlight.apply_line_highlight(buf, snippet_offset - 1, snippet_offset, "VimTeacherSeparator")
	else
		highlight.apply_line_highlight(buf, snippet_offset - 2, snippet_offset - 1, "VimTeacherSeparator")
	end

	if goal_row then
		for _, region in ipairs(goal_hl_regions) do
			highlight.apply_col_highlight(buf, goal_row, region.s, region.e, region.g)
		end
	end

	if goal_text_row then
		for _, region in ipairs(goal_text_hl_regions) do
			highlight.apply_col_highlight(buf, goal_text_row, region.s, region.e, region.g)
		end
	end

	highlight.apply_line_highlight(buf, snippet_end + 2, snippet_end + 3, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, hint_start, hint_end, "VimTeacherHint")

	return {
		snippet_offset = snippet_offset,
		snippet_end = snippet_end,
		progress_line = progress_line,
	}
end

return M
