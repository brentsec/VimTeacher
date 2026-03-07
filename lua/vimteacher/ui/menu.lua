-- vimteacher/ui/menu.lua
-- Topic menu rendering and layout helpers.

local common = require("vimteacher.ui.common")
local highlight = require("vimteacher.highlight")

local M = {}

-- Menu sizing heuristics
local DEFAULT_MENU_BOX_WIDTH = 74 -- inner width (chars between the │ borders)
local MENU_FILL_RATIO = 0.96
local MENU_MIN_TOTAL_WIDTH = 40

--- Compute menu width and side padding from current window width.
--- @param win number|nil Window handle
--- @return table { box_width: number, left_pad: number, right_pad: number }
function M.compute_menu_layout(win)
	local target_win = win
	if not target_win or not vim.api.nvim_win_is_valid(target_win) then
		target_win = vim.api.nvim_get_current_win()
	end

	local win_width = vim.api.nvim_win_get_width(target_win)
	if win_width < 4 then
		win_width = 4
	end

	local desired_total = math.floor(win_width * MENU_FILL_RATIO)
	local min_total = math.min(win_width, DEFAULT_MENU_BOX_WIDTH + 2)
	if desired_total < min_total then
		desired_total = min_total
	end
	if desired_total < MENU_MIN_TOTAL_WIDTH then
		desired_total = math.min(win_width, MENU_MIN_TOTAL_WIDTH)
	end
	if desired_total > win_width then
		desired_total = win_width
	end
	if desired_total < 4 then
		desired_total = 4
	end

	local left_pad = math.max(0, math.floor((win_width - desired_total) / 2))
	local right_pad = math.max(0, win_width - desired_total - left_pad)

	return {
		box_width = math.max(2, desired_total - 2),
		left_pad = left_pad,
		right_pad = right_pad,
	}
end

--- Add horizontal outer padding so menu can be centered.
--- @param line string
--- @param layout table
--- @return string
local function with_outer_padding(line, layout)
	return string.rep(" ", layout.left_pad) .. line .. string.rep(" ", layout.right_pad)
end

--- Build a menu row with stable column widths, avoiding string.format edge cases.
--- @param num_text string
--- @param topic_text string
--- @param best_time_text string
--- @param best_acc_text string
--- @param topic_col_width number
--- @return string
function M.build_menu_row(num_text, topic_text, best_time_text, best_acc_text, topic_col_width)
	return common.pad_to_width("  " .. common.as_text(num_text), 6)
		.. common.pad_to_width(common.as_text(topic_text), topic_col_width)
		.. common.pad_to_width(common.as_text(best_time_text), 12)
		.. common.as_text(best_acc_text)
end

--- Build a bordered content line: │  content...padded...  │
--- @param content string The content (can be empty for blank line)
--- @param layout table
--- @return string
function M.bordered(content, layout)
	local inner = "  " .. content
	local padded = common.pad_to_width(inner, layout.box_width)
	return with_outer_padding("│" .. padded .. "│", layout)
end

--- Build the top border: ╭──...──╮
--- @param layout table
--- @return string
function M.border_top(layout)
	return with_outer_padding("╭" .. string.rep("─", layout.box_width) .. "╮", layout)
end

--- Build the bottom border: ╰──...──╯
--- @param layout table
--- @return string
function M.border_bottom(layout)
	return with_outer_padding("╰" .. string.rep("─", layout.box_width) .. "╯", layout)
end

--- Build an inner separator line inside the box.
--- @param layout table
--- @return string
local function inner_separator(layout)
	return M.bordered(string.rep("─", math.max(0, layout.box_width - 4)), layout)
end

--- Build a subtitle separator: │  ┈┈┈ Text ┈┈┈...┈  │
--- @param text string The subtitle text
--- @param layout table
--- @return string
local function subtitle_line(text, layout)
	local prefix = "┈┈┈ "
	local content = prefix .. text .. " "
	local display_width = vim.api.nvim_strwidth(content)
	local remaining = layout.box_width - 4 - display_width
	if remaining > 0 then
		content = content .. string.rep("┈", remaining)
	end
	return M.bordered(content, layout)
end

--- Render the topic selection menu.
--- @param buf number Buffer handle
--- @param sections table Ordered list of {title, lessons={{name, title}}} section tables
--- @param all_stats table Stats data keyed by lesson name
--- @param win number|nil Window handle (for responsive sizing)
function M.render_menu(buf, sections, all_stats, win)
	sections = type(sections) == "table" and sections or {}
	all_stats = type(all_stats) == "table" and all_stats or {}

	local menu_layout = M.compute_menu_layout(win)
	local topic_col_width = math.max(20, menu_layout.box_width - 33)
	local lines = {}
	local row_to_lesson = {}
	local row_to_lesson_col = {}

	lines[#lines + 1] = M.border_top(menu_layout)
	lines[#lines + 1] = M.bordered("", menu_layout)

	local logo_start = #lines
	for _, logo_line in ipairs(common.LOGO) do
		lines[#lines + 1] = M.bordered(logo_line, menu_layout)
	end

	lines[#lines + 1] = M.bordered("", menu_layout)

	local subtitle_row = #lines
	lines[#lines + 1] = subtitle_line("Select a Topic", menu_layout)

	lines[#lines + 1] = M.bordered("", menu_layout)

	local hint_row = #lines
	lines[#lines + 1] = M.bordered("Type a number or highlight a lesson and press Enter to start, or q to quit", menu_layout)
	lines[#lines + 1] = M.bordered("", menu_layout)

	local header_row = #lines
	lines[#lines + 1] = M.bordered(M.build_menu_row("#", "Topic", "Best Time", "Best Accuracy", topic_col_width), menu_layout)

	local header_sep_row = #lines
	lines[#lines + 1] = inner_separator(menu_layout)

	local menu_start = #lines
	local lesson_num = 0
	local section_rows = {}

	for sec_idx, section in ipairs(sections) do
		local section_title = common.as_text(section.title)
		local section_lessons = type(section.lessons) == "table" and section.lessons or {}

		if sec_idx > 1 then
			lines[#lines + 1] = M.bordered("", menu_layout)
		end
		section_rows[#section_rows + 1] = #lines
		lines[#lines + 1] = M.bordered("  " .. section_title, menu_layout)

		for _, lesson in ipairs(section_lessons) do
			lesson_num = lesson_num + 1
			local ls = all_stats[lesson.name]
			local best_time = "  --"
			local best_acc = "  --"
			if ls then
				local best_time_num = tonumber(ls.best_time)
				if best_time_num and best_time_num > 0 then
					best_time = string.format("%.1fs", best_time_num)
				end
				local best_acc_num = tonumber(ls.best_accuracy)
				if best_acc_num and best_acc_num > 0 then
					best_acc = string.format("%d%%", best_acc_num)
				end
			end
			local lesson_num_text = lesson_num .. "."
			local lesson_row = M.build_menu_row(
				lesson_num_text,
				common.as_text(lesson.title),
				best_time,
				best_acc,
				topic_col_width
			)
			local bordered_row = M.bordered(lesson_row, menu_layout)
			lines[#lines + 1] = bordered_row
			row_to_lesson[#lines] = lesson_num
			local num_col = bordered_row:find(lesson_num_text, 1, true)
			if num_col then
				row_to_lesson_col[#lines] = num_col - 1
			end
		end
	end
	local menu_end = #lines

	lines[#lines + 1] = M.bordered("", menu_layout)

	local bottom_sep_row = #lines
	lines[#lines + 1] = inner_separator(menu_layout)

	lines[#lines + 1] = M.bordered("", menu_layout)
	lines[#lines + 1] = M.border_bottom(menu_layout)

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.api.nvim_buf_set_var(buf, "vimteacher_menu_row_to_lesson", row_to_lesson)
	vim.api.nvim_buf_set_var(buf, "vimteacher_menu_row_to_col", row_to_lesson_col)

	highlight.apply_line_highlight(buf, 0, 1, "VimTeacherBorder")
	highlight.apply_line_highlight(buf, #lines - 1, #lines, "VimTeacherBorder")

	for row = 1, #lines - 2 do
		local line_text = lines[row + 1]
		if line_text then
			local left_border = line_text:find("│", 1, true)
			local right_border = line_text:match(".*()│")
			if left_border then
				highlight.apply_col_highlight(buf, row, left_border - 1, left_border + 2, "VimTeacherBorder")
			end
			if right_border and right_border ~= left_border then
				highlight.apply_col_highlight(buf, row, right_border - 1, right_border + 2, "VimTeacherBorder")
			end
		end
	end

	local logo_groups = {
		"VimTeacherLogo1",
		"VimTeacherLogo2",
		"VimTeacherLogo3",
		"VimTeacherLogo4",
		"VimTeacherLogo5",
	}
	for i = 1, #common.LOGO do
		local row = logo_start + (i - 1)
		local line_text = lines[row + 1]
		if line_text then
			local left_border = line_text:find("│", 1, true)
			local right_border = line_text:match(".*()│")
			if left_border and right_border and right_border > left_border then
				highlight.apply_col_highlight(buf, row, left_border + 2, right_border - 1, logo_groups[i])
			end
		end
	end

	highlight.apply_line_highlight(buf, subtitle_row, subtitle_row + 1, "VimTeacherMenuSep")
	do
		local st_line = lines[subtitle_row + 1]
		if st_line then
			local st_start, st_end = st_line:find("Select a Topic")
			if st_start then
				highlight.apply_col_highlight(buf, subtitle_row, st_start - 1, st_end, "VimTeacherSubtitle")
			end
		end
	end

	highlight.apply_line_highlight(buf, header_row, header_row + 1, "VimTeacherStatsHeader")
	highlight.apply_line_highlight(buf, header_sep_row, header_sep_row + 1, "VimTeacherMenuSep")
	highlight.apply_line_highlight(buf, bottom_sep_row, bottom_sep_row + 1, "VimTeacherMenuSep")

	for idx = 0, menu_end - menu_start - 1 do
		local row = menu_start + idx
		highlight.apply_line_highlight(buf, row, row + 1, "VimTeacherMenuText")

		local item_line = lines[row + 1]
		if item_line then
			local num_start, num_end = item_line:find("%d+%.")
			if num_start then
				highlight.apply_col_highlight(buf, row, num_start - 1, num_end, "VimTeacherMenuNumber")
			end

			for _, pat in ipairs({ "%d+%.%d+s", "%d+%%", "%-%-" }) do
				local s, e = item_line:find(pat, 1)
				while s do
					highlight.apply_col_highlight(buf, row, s - 1, e, "VimTeacherMenuStat")
					s, e = item_line:find(pat, e + 1)
				end
			end
		end
	end

	for _, row in ipairs(section_rows) do
		highlight.apply_line_highlight(buf, row, row + 1, "VimTeacherMenuSection")
	end

	highlight.apply_line_highlight(buf, hint_row, hint_row + 1, "VimTeacherHint")
end

return M
