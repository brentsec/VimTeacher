-- vimteacher/buffer.lua
-- Buffer creation, layout rendering, and screen management

local highlight = require("vimteacher.highlight")
local stats = require("vimteacher.stats")

local M = {}

-- Stored layout metadata for the current render
local layout_meta = {
	snippet_offset = 0,
	snippet_end = 0,
}

local SEPARATOR = string.rep("─", 68)
local build_menu_row

-- Menu sizing heuristics
local DEFAULT_MENU_BOX_WIDTH = 74 -- inner width (chars between the │ borders)
local MENU_FILL_RATIO = 0.96
local MENU_MIN_TOTAL_WIDTH = 40

-- ASCII art logo: heavy blocks for "Vim", box-drawing for "Teacher"
local LOGO = {
	"  ██╗   ██╗██╗███╗   ███╗",
	"  ██║   ██║██║████╗ ████║  ╔╦╗╔═╗╔═╗╔═╗╦ ╦╔═╗╦═╗",
	"  ╚██╗ ██╔╝██║██╔████╔██║   ║ ║╣ ╠═╣║  ╠═╣║╣ ╠╦╝",
	"   ╚████╔╝ ██║██║╚██╔╝██║   ╩ ╚═╝╩ ╩╚═╝╩ ╩╚═╝╩╚═",
	"    ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

--- Compute menu width and side padding from current window width.
--- @param win number|nil Window handle
--- @return table { box_width: number, left_pad: number, right_pad: number }
local function compute_menu_layout(win)
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

--- Truncate a string to max display width.
--- @param s string
--- @param width number
--- @return string
local function truncate_to_width(s, width)
	if width <= 0 then
		return ""
	end
	if vim.api.nvim_strwidth(s) <= width then
		return s
	end

	local chars = vim.fn.strchars(s)
	for n = chars, 0, -1 do
		local candidate = vim.fn.strcharpart(s, 0, n)
		if vim.api.nvim_strwidth(candidate) <= width then
			return candidate
		end
	end
	return ""
end

--- Coerce display values to strings for robust rendering.
--- @param v any
--- @return string
local function as_text(v)
	if type(v) == "string" then
		return v
	end
	if v == nil then
		return ""
	end
	return tostring(v)
end

--- Pad a string to exactly `width` display columns.
--- @param s string Input string
--- @param width number Desired display width
--- @return string Padded string
local function pad_to_width(s, width)
	if width <= 0 then
		return ""
	end
	local display_width = vim.api.nvim_strwidth(s)
	if display_width >= width then
		return truncate_to_width(s, width)
	end
	return s .. string.rep(" ", width - display_width)
end

--- Build a menu row with stable column widths, avoiding string.format edge cases.
--- @param num_text string
--- @param topic_text string
--- @param best_time_text string
--- @param best_acc_text string
--- @param topic_col_width number
--- @return string
build_menu_row = function(num_text, topic_text, best_time_text, best_acc_text, topic_col_width)
	return pad_to_width("  " .. as_text(num_text), 6)
		.. pad_to_width(as_text(topic_text), topic_col_width)
		.. pad_to_width(as_text(best_time_text), 12)
		.. as_text(best_acc_text)
end

--- Build a bordered content line: │  content...padded...  │
--- @param content string The content (can be empty for blank line)
--- @param layout table
--- @return string
local function bordered(content, layout)
	local inner = "  " .. content
	local padded = pad_to_width(inner, layout.box_width)
	return with_outer_padding("│" .. padded .. "│", layout)
end

--- Build the top border: ╭──...──╮
--- @param layout table
--- @return string
local function border_top(layout)
	return with_outer_padding("╭" .. string.rep("─", layout.box_width) .. "╮", layout)
end

--- Build the bottom border: ╰──...──╯
--- @param layout table
--- @return string
local function border_bottom(layout)
	return with_outer_padding("╰" .. string.rep("─", layout.box_width) .. "╯", layout)
end

--- Build an inner separator line inside the box.
--- @param layout table
--- @return string
local function inner_separator(layout)
	return bordered(string.rep("─", math.max(0, layout.box_width - 4)), layout)
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
	return bordered(content, layout)
end

--- Create a scratch buffer and configure the window.
--- @return number buf Buffer handle
--- @return number win Window handle
function M.create()
	local buf = vim.api.nvim_create_buf(false, true)

	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "vimteacher"
	vim.bo[buf].undolevels = -1

	local win = nil
	do
		local ok, cur = pcall(vim.api.nvim_get_current_win)
		if ok and cur and vim.api.nvim_win_is_valid(cur) then
			win = cur
		else
			for _, w in ipairs(vim.api.nvim_list_wins()) do
				if vim.api.nvim_win_is_valid(w) then
					win = w
					break
				end
			end
		end
	end

	if not win then
		vim.cmd("enew")
		win = vim.api.nvim_get_current_win()
	end

	local ok_set = pcall(vim.api.nvim_win_set_buf, win, buf)
	if not ok_set then
		if pcall(vim.api.nvim_set_current_win, win) then
			ok_set = pcall(vim.api.nvim_set_current_buf, buf)
		end
	end
	if not ok_set then
		win = vim.api.nvim_get_current_win()
		pcall(vim.api.nvim_set_current_buf, buf)
	end
	if not vim.api.nvim_win_is_valid(win) then
		win = vim.api.nvim_get_current_win()
	end

	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].cursorline = true
	vim.wo[win].wrap = false
	vim.wo[win].scrolloff = 0
	vim.wo[win].sidescrolloff = 0
	vim.wo[win].colorcolumn = ""
	vim.wo[win].foldmethod = "manual"
	vim.wo[win].foldenable = false

	return buf, win
end

--- Render the topic selection menu.
--- @param buf number Buffer handle
--- @param sections table Ordered list of {title, lessons={{name, title}}} section tables
--- @param all_stats table Stats data keyed by lesson name
--- @param win number|nil Window handle (for responsive sizing)
function M.render_menu(buf, sections, all_stats, win)
	sections = type(sections) == "table" and sections or {}
	all_stats = type(all_stats) == "table" and all_stats or {}

	local menu_layout = compute_menu_layout(win)
	local topic_col_width = math.max(20, menu_layout.box_width - 33)
	local lines = {}

	-- Top border
	lines[#lines + 1] = border_top(menu_layout)
	lines[#lines + 1] = bordered("", menu_layout)

	-- Logo (5 lines)
	local logo_start = #lines -- 0-indexed first logo line
	for _, logo_line in ipairs(LOGO) do
		lines[#lines + 1] = bordered(logo_line, menu_layout)
	end

	lines[#lines + 1] = bordered("", menu_layout)

	-- Subtitle separator
	local subtitle_row = #lines
	lines[#lines + 1] = subtitle_line("Select a Topic", menu_layout)

	lines[#lines + 1] = bordered("", menu_layout)

	-- Top hint bar
	local hint_row = #lines
	lines[#lines + 1] = bordered("Type a number to start, or q to quit", menu_layout)
	lines[#lines + 1] = bordered("", menu_layout)

	-- Column header
	local header_row = #lines
	lines[#lines + 1] =
		bordered(build_menu_row("#", "Topic", "Best Time", "Best Accuracy", topic_col_width), menu_layout)

	-- Header underline
	local header_sep_row = #lines
	lines[#lines + 1] = inner_separator(menu_layout)

	-- Menu items with section headers
	local menu_start = #lines
	local lesson_num = 0
	local section_rows = {}

	for sec_idx, section in ipairs(sections) do
		local section_title = as_text(section.title)
		local section_lessons = type(section.lessons) == "table" and section.lessons or {}

		-- Blank line before section (except first)
		if sec_idx > 1 then
			lines[#lines + 1] = bordered("", menu_layout)
		end
		-- Section header
		section_rows[#section_rows + 1] = #lines
		lines[#lines + 1] = bordered("  " .. section_title, menu_layout)

		-- Lessons in this section
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
			lines[#lines + 1] = bordered(
				build_menu_row(lesson_num .. ".", as_text(lesson.title), best_time, best_acc, topic_col_width),
				menu_layout
			)
		end
	end
	local menu_end = #lines

	lines[#lines + 1] = bordered("", menu_layout)

	-- Bottom separator inside box
	local bottom_sep_row = #lines
	lines[#lines + 1] = inner_separator(menu_layout)

	lines[#lines + 1] = bordered("", menu_layout)

	-- Bottom border
	lines[#lines + 1] = border_bottom(menu_layout)

	-- Write to buffer
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- ── Apply highlights ──

	-- Top and bottom border lines
	highlight.apply_line_highlight(buf, 0, 1, "VimTeacherBorder")
	highlight.apply_line_highlight(buf, #lines - 1, #lines, "VimTeacherBorder")

	-- Border │ characters on all intermediate lines
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

	-- Logo gradient: each line gets a different color
	local logo_groups = {
		"VimTeacherLogo1",
		"VimTeacherLogo2",
		"VimTeacherLogo3",
		"VimTeacherLogo4",
		"VimTeacherLogo5",
	}
	for i = 1, #LOGO do
		local row = logo_start + (i - 1)
		local line_text = lines[row + 1]
		if line_text then
			local left_border = line_text:find("│", 1, true)
			local right_border = line_text:match(".*()│")
			if left_border and right_border and right_border > left_border then
				-- Apply gradient only inside the borders.
				highlight.apply_col_highlight(buf, row, left_border + 2, right_border - 1, logo_groups[i])
			end
		end
	end

	-- Subtitle: dim ┈ chars with purple "Select a Topic" overlay
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

	-- Column header
	highlight.apply_line_highlight(buf, header_row, header_row + 1, "VimTeacherStatsHeader")

	-- Inner separators
	highlight.apply_line_highlight(buf, header_sep_row, header_sep_row + 1, "VimTeacherMenuSep")
	highlight.apply_line_highlight(buf, bottom_sep_row, bottom_sep_row + 1, "VimTeacherMenuSep")

	-- Menu items: base text color, then overlay number and stats
	for idx = 0, menu_end - menu_start - 1 do
		local row = menu_start + idx
		highlight.apply_line_highlight(buf, row, row + 1, "VimTeacherMenuText")

		local item_line = lines[row + 1]
		if item_line then
			-- Number overlay (e.g. "1.")
			local num_start, num_end = item_line:find("%d+%.")
			if num_start then
				highlight.apply_col_highlight(buf, row, num_start - 1, num_end, "VimTeacherMenuNumber")
			end

			-- Stat value overlays (time, percentage, dashes)
			for _, pat in ipairs({ "%d+%.%d+s", "%d+%%", "%-%-" }) do
				local s, e = item_line:find(pat, 1)
				while s do
					highlight.apply_col_highlight(buf, row, s - 1, e, "VimTeacherMenuStat")
					s, e = item_line:find(pat, e + 1)
				end
			end
		end
	end

	-- Section headers
	for _, row in ipairs(section_rows) do
		highlight.apply_line_highlight(buf, row, row + 1, "VimTeacherMenuSection")
	end

	-- Hint line
	highlight.apply_line_highlight(buf, hint_row, hint_row + 1, "VimTeacherHint")
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
function M.render(buf, opts)
	local lines = {}

	-- Title
	lines[#lines + 1] = "  " .. opts.title
	lines[#lines + 1] = ""

	-- Description
	local desc_start = #lines
	for _, line in ipairs(opts.description) do
		lines[#lines + 1] = "  " .. line
	end
	local desc_end = #lines
	lines[#lines + 1] = ""

	-- Separator + Progress + Separator (omitted for info lessons)
	local progress_line = nil
	if opts.progress then
		lines[#lines + 1] = "  " .. SEPARATOR
		progress_line = #lines
		local completed = opts.progress - 1
		local remaining = opts.max_progress - completed
		local bar = string.rep("#", completed) .. string.rep(".", remaining)
		lines[#lines + 1] = string.format("  Challenge %d/%d   [%s]", opts.progress, opts.max_progress, bar)
		lines[#lines + 1] = "  " .. SEPARATOR
	else
		lines[#lines + 1] = "  " .. SEPARATOR
	end

	-- Goal bar (insert lessons with key reveal)
	local goal_row = nil
	local goal_hl_regions = {}
	if opts.goal then
		goal_row = #lines
		local parts = {}
		local byte_pos = 0

		local function add(text, hl_group)
			if not text then
				return
			end
			parts[#parts + 1] = text
			if hl_group then
				goal_hl_regions[#goal_hl_regions + 1] = { s = byte_pos, e = byte_pos + #text, g = hl_group }
			end
			byte_pos = byte_pos + #text
		end

		add("  ")
		add("─── ", "VimTeacherSeparator")
		add(opts.goal.action, "VimTeacherGoalText")
		add("  ")
		add(opts.goal.char, "VimTeacherInsertHint")
		add("  ")
		add(opts.goal.preposition, "VimTeacherGoalText")
		add(" ── ", "VimTeacherSeparator")
		add("press", "VimTeacherGoalText")
		add("  ")
		add(opts.goal.key, "VimTeacherInsertHint")
		add("  ")

		local display_width = vim.api.nvim_strwidth(table.concat(parts, ""))
		local remaining = 68 + 2 - display_width
		if remaining > 0 then
			add(string.rep("─", remaining), "VimTeacherSeparator")
		end

		lines[#lines + 1] = table.concat(parts, "")
	end

	-- Goal text bar (text-only instruction, no key reveal)
	local goal_text_row = nil
	local goal_text_hl_regions = {}
	if not opts.goal and opts.goal_text then
		goal_text_row = #lines
		local parts = {}
		local byte_pos = 0

		local function add_gt(text, hl_group)
			if not text then
				return
			end
			parts[#parts + 1] = text
			if hl_group then
				goal_text_hl_regions[#goal_text_hl_regions + 1] = { s = byte_pos, e = byte_pos + #text, g = hl_group }
			end
			byte_pos = byte_pos + #text
		end

		add_gt("  ")
		add_gt("─── ", "VimTeacherSeparator")
		add_gt(opts.goal_text, "VimTeacherGoalText")
		add_gt(" ")

		local display_width = vim.api.nvim_strwidth(table.concat(parts, ""))
		local remaining = 68 + 2 - display_width
		if remaining > 0 then
			add_gt(string.rep("─", remaining), "VimTeacherSeparator")
		end

		lines[#lines + 1] = table.concat(parts, "")
	end

	lines[#lines + 1] = ""

	-- Code snippet zone
	local snippet_offset = #lines -- 0-indexed line where snippet starts
	for _, line in ipairs(opts.snippet_lines) do
		lines[#lines + 1] = line
	end
	local snippet_end = #lines - 1 -- 0-indexed last line of snippet

	lines[#lines + 1] = ""

	-- Bottom separator + hints
	lines[#lines + 1] = "  " .. SEPARATOR
	local hint_start = #lines
	for _, line in ipairs(opts.hint_lines) do
		lines[#lines + 1] = "  " .. line
	end
	-- Navigation hints (shown during challenges, not info lessons)
	if opts.progress then
		lines[#lines + 1] = "  " .. (opts.nav_hint_line or "[q] Menu  [Q] Restart lesson")
	end
	local hint_end = #lines

	-- Write to buffer
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- Store layout metadata
	layout_meta.snippet_offset = snippet_offset
	layout_meta.snippet_end = snippet_end
	layout_meta.progress_line = progress_line

	-- Apply highlights (layout namespace)
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)

	highlight.apply_line_highlight(buf, 0, 1, "VimTeacherTitle")
	highlight.apply_line_highlight(buf, desc_start, desc_end, "VimTeacherHint")

	-- Separators + Progress
	if progress_line then
		highlight.apply_line_highlight(buf, snippet_offset - 3, snippet_offset - 2, "VimTeacherSeparator")
		highlight.apply_line_highlight(buf, progress_line, progress_line + 1, "VimTeacherProgress")
		highlight.apply_line_highlight(buf, snippet_offset - 1, snippet_offset, "VimTeacherSeparator")
	else
		highlight.apply_line_highlight(buf, snippet_offset - 2, snippet_offset - 1, "VimTeacherSeparator")
	end

	-- Goal bar highlights
	if goal_row then
		for _, region in ipairs(goal_hl_regions) do
			highlight.apply_col_highlight(buf, goal_row, region.s, region.e, region.g)
		end
	end

	-- Goal text bar highlights
	if goal_text_row then
		for _, region in ipairs(goal_text_hl_regions) do
			highlight.apply_col_highlight(buf, goal_text_row, region.s, region.e, region.g)
		end
	end

	-- Bottom separator + hints
	highlight.apply_line_highlight(buf, snippet_end + 2, snippet_end + 3, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, hint_start, hint_end, "VimTeacherHint")
end

--- Render the stats overlay (replaces snippet zone content between challenges).
--- @param buf number Buffer handle
--- @param opts table Stats options
---   opts.title: string (lesson title)
---   opts.progress: number (current challenge just completed)
---   opts.max_progress: number
---   opts.time_secs: number
---   opts.best_time: number|nil
---   opts.speed_pct: number
---   opts.avg_time: number|nil
---   opts.accuracy_pct: number
---   opts.actual_moves: number
---   opts.optimal_moves: number
---   opts.description: string[] (lesson description for re-render)
---   opts.hint_lines: string[]
function M.render_challenge_stats(buf, opts)
	local lines = {}

	-- Title
	lines[#lines + 1] = "  " .. opts.title
	lines[#lines + 1] = ""

	-- Description (abbreviated)
	for _, line in ipairs(opts.description) do
		lines[#lines + 1] = "  " .. line
	end
	lines[#lines + 1] = ""

	-- Separator + Progress (completed) + Separator
	lines[#lines + 1] = "  " .. SEPARATOR
	local completed = opts.progress
	local remaining = opts.max_progress - completed
	local bar = string.rep("#", completed) .. string.rep(".", remaining)
	lines[#lines + 1] = string.format("  Challenge %d/%d   [%s]", opts.progress, opts.max_progress, bar)
	lines[#lines + 1] = "  " .. SEPARATOR
	lines[#lines + 1] = ""

	-- Stats display
	lines[#lines + 1] = "  CHALLENGE COMPLETE!"
	lines[#lines + 1] = ""

	local best_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
	lines[#lines + 1] = string.format("  Time:      %.1fs        Best: %s", opts.time_secs, best_str)

	lines[#lines + 1] = string.format("  Speed:     %d%%          (vs PB of %s)", opts.speed_pct, best_str)

	lines[#lines + 1] = string.format(
		"  Accuracy:  %d%%          (%d moves / %d optimal)",
		opts.accuracy_pct,
		opts.actual_moves,
		opts.optimal_moves
	)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. SEPARATOR
	lines[#lines + 1] = ""

	-- Write to buffer
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- Apply highlights
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_target, 0, -1)

	highlight.apply_line_highlight(buf, 0, 1, "VimTeacherTitle")

	-- Find the "CHALLENGE COMPLETE!" line and highlight it
	for i, line in ipairs(lines) do
		if line:find("CHALLENGE COMPLETE!") then
			highlight.apply_line_highlight(buf, i - 1, i, "VimTeacherComplete")
		end
	end
end

--- Render the final completion screen for a lesson with session stats summary.
--- @param buf number Buffer handle
--- @param opts table Completion options
---   opts.title: string (lesson title)
---   opts.max_challenges: number (total challenges completed)
---   opts.session_challenges: table[] (list of {time, accuracy_pct, moves, optimal})
---   opts.best_time: number|nil (personal best from persistent stats)
---   opts.avg_time: number|nil (running average from persistent stats)
function M.render_completion(buf, opts)
	-- Compute aggregated session stats
	local total_time = 0
	local total_moves = 0
	local total_optimal = 0

	for _, c in ipairs(opts.session_challenges or {}) do
		total_time = total_time + c.time
		total_moves = total_moves + c.moves
		total_optimal = total_optimal + stats.normalize_optimal_moves(c.optimal, c.moves)
	end

	local num_challenges = #(opts.session_challenges or {})
	local avg_time = num_challenges > 0 and (total_time / num_challenges) or 0
	local overall_accuracy = stats.calc_overall_accuracy_pct(total_optimal, total_moves)

	local lines = {
		"",
		"  LESSON COMPLETE!",
		"",
		"  " .. opts.title,
		"  You completed all " .. opts.max_challenges .. " challenges.",
		"",
		"  " .. SEPARATOR,
		"  Session Summary",
		"  " .. SEPARATOR,
		"",
	}

	local pb_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
	lines[#lines + 1] =
		string.format("  Total time:     %-12sPersonal best:  %s", string.format("%.1fs", total_time), pb_str)

	-- Speed %: bounded score against personal-best lesson time.
	local speed_pct = stats.calc_speed_pct(opts.best_time, total_time)
	local pb_hist_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
	lines[#lines + 1] = string.format(
		"  Avg/challenge:  %-12sSpeed: %d%% (vs PB of %s)",
		string.format("%.1fs", avg_time),
		speed_pct,
		pb_hist_str
	)

	lines[#lines + 1] = string.format(
		"  Accuracy:       %-12s(%d moves / %d optimal)",
		string.format("%d%%", overall_accuracy),
		total_moves,
		total_optimal
	)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. SEPARATOR
	lines[#lines + 1] = ""

	local nav_start = #lines
	lines[#lines + 1] = "  What's next:"
	lines[#lines + 1] = "    n   Move to the next topic"
	lines[#lines + 1] = "    p   Go back to the previous topic"
	lines[#lines + 1] = "    r   Restart this topic"
	lines[#lines + 1] = "    m   Return to topic menu"
	lines[#lines + 1] = "    q   Quit the tutorial"
	local nav_end = #lines

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. SEPARATOR
	lines[#lines + 1] = ""

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	-- Apply highlights
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_target, 0, -1)

	highlight.apply_line_highlight(buf, 1, 2, "VimTeacherComplete")
	highlight.apply_line_highlight(buf, 3, 5, "VimTeacherTitle")
	highlight.apply_line_highlight(buf, 6, 7, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, 7, 8, "VimTeacherStatsHeader")
	highlight.apply_line_highlight(buf, 8, 9, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, nav_end, nav_end + 2, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, nav_start, nav_end, "VimTeacherHint")
end

--- Get the snippet zone boundaries from the last render.
--- @return number snippet_offset 0-indexed first line of snippet
--- @return number snippet_end 0-indexed last line of snippet
function M.get_snippet_bounds()
	return layout_meta.snippet_offset, layout_meta.snippet_end
end

--- Update the elapsed timer display on the progress bar line.
--- @param buf number Buffer handle
--- @param elapsed_secs number Elapsed time in seconds
function M.update_timer(buf, elapsed_secs)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if not layout_meta.progress_line then
		return
	end

	local mins = math.floor(elapsed_secs / 60)
	local secs = math.floor(elapsed_secs % 60)
	local text = string.format("  %02d:%02d", mins, secs)

	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_timer, 0, -1)
	vim.api.nvim_buf_set_extmark(buf, highlight.ns_timer, layout_meta.progress_line, 0, {
		virt_text = { { text, "VimTeacherTimer" } },
		virt_text_pos = "eol",
	})
end

--- Clear the elapsed timer display.
--- @param buf number Buffer handle
function M.clear_timer(buf)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_timer, 0, -1)
	layout_meta.progress_line = nil
end

return M
