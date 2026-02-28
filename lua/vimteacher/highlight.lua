-- vimteacher/highlight.lua
-- Highlight group definitions and extmark management
-- Uses three namespaces: layout (decorations), target (game element), timer (elapsed clock)

local M = {}

M.ns_layout = nil
M.ns_target = nil
M.ns_timer = nil

--- Initialize highlight groups and namespaces.
function M.setup()
	M.ns_layout = vim.api.nvim_create_namespace("vimteacher_layout")
	M.ns_target = vim.api.nvim_create_namespace("vimteacher_target")
	M.ns_timer = vim.api.nvim_create_namespace("vimteacher_timer")

	-- Title: blue bold
	vim.api.nvim_set_hl(0, "VimTeacherTitle", {
		bold = true,
		fg = "#61AFEF",
	})

	-- Separator: muted gray
	vim.api.nvim_set_hl(0, "VimTeacherSeparator", {
		fg = "#5C6370",
	})

	-- Target: green background, dark foreground
	vim.api.nvim_set_hl(0, "VimTeacherTarget", {
		bg = "#98C379",
		fg = "#282C34",
		bold = true,
	})

	-- Success flash: gold/yellow background
	vim.api.nvim_set_hl(0, "VimTeacherSuccess", {
		bg = "#E5C07B",
		fg = "#282C34",
		bold = true,
	})

	-- Progress bar: green text
	vim.api.nvim_set_hl(0, "VimTeacherProgress", {
		fg = "#98C379",
	})

	-- Elapsed timer: cyan bold
	vim.api.nvim_set_hl(0, "VimTeacherTimer", {
		fg = "#56B6C2",
		bold = true,
	})

	-- Hint text: gray italic
	vim.api.nvim_set_hl(0, "VimTeacherHint", {
		fg = "#5C6370",
		italic = true,
	})

	-- Completion: green bold
	vim.api.nvim_set_hl(0, "VimTeacherComplete", {
		fg = "#98C379",
		bold = true,
	})

	-- Stats header: bright white bold
	vim.api.nvim_set_hl(0, "VimTeacherStatsHeader", {
		fg = "#ABB2BF",
		bold = true,
	})

	-- Menu item: default with slightly brighter foreground
	vim.api.nvim_set_hl(0, "VimTeacherMenuItem", {
		fg = "#ABB2BF",
	})

	-- Menu number: purple bold (for selectable items)
	vim.api.nvim_set_hl(0, "VimTeacherMenuNumber", {
		fg = "#C678DD",
		bold = true,
	})

	-- Logo gradient: purple (#C678DD) → red (#E06C75), 5 steps
	vim.api.nvim_set_hl(0, "VimTeacherLogo1", { fg = "#C678DD", bold = true })
	vim.api.nvim_set_hl(0, "VimTeacherLogo2", { fg = "#CE63BF", bold = true })
	vim.api.nvim_set_hl(0, "VimTeacherLogo3", { fg = "#D64EA1", bold = true })
	vim.api.nvim_set_hl(0, "VimTeacherLogo4", { fg = "#DE3983", bold = true })
	vim.api.nvim_set_hl(0, "VimTeacherLogo5", { fg = "#E06C75", bold = true })

	-- Border: muted purple
	vim.api.nvim_set_hl(0, "VimTeacherBorder", { fg = "#7C6F9F" })

	-- Menu subtitle: purple bold
	vim.api.nvim_set_hl(0, "VimTeacherSubtitle", { fg = "#C678DD", bold = true })

	-- Menu topic text: bright white
	vim.api.nvim_set_hl(0, "VimTeacherMenuText", { fg = "#D4D4D4" })

	-- Menu stat values: cyan
	vim.api.nvim_set_hl(0, "VimTeacherMenuStat", { fg = "#56B6C2" })

	-- Inner separator: dim purple
	vim.api.nvim_set_hl(0, "VimTeacherMenuSep", { fg = "#5C4F7C" })

	-- Menu section header: teal/cyan bold
	vim.api.nvim_set_hl(0, "VimTeacherMenuSection", { fg = "#56B6C2", bold = true })

	-- Insert mode hint: gold bold (shows what to type)
	vim.api.nvim_set_hl(0, "VimTeacherInsertHint", { fg = "#E5C07B", bold = true })

	-- Goal bar text: readable white for action labels
	vim.api.nvim_set_hl(0, "VimTeacherGoalText", { fg = "#ABB2BF" })

	-- Search target: blue bg, distinct from Vim's yellow hlsearch
	vim.api.nvim_set_hl(0, "VimTeacherSearchTarget", {
		bg = "#61AFEF",
		fg = "#282C34",
		bold = true,
		underline = true,
	})
end

--- Apply a highlight group to a line range in the layout namespace.
--- @param buf number Buffer handle
--- @param start_row number 0-indexed start line
--- @param end_row number 0-indexed end line (exclusive)
--- @param hl_group string Highlight group name
function M.apply_line_highlight(buf, start_row, end_row, hl_group)
	for row = start_row, end_row - 1 do
		local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
		if line and #line > 0 then
			vim.api.nvim_buf_set_extmark(buf, M.ns_layout, row, 0, {
				end_col = #line,
				hl_group = hl_group,
				priority = 100,
			})
		end
	end
end

--- Apply a highlight group to a specific column range on a single line.
--- @param buf number Buffer handle
--- @param row number 0-indexed line number
--- @param col_start number 0-indexed start column (byte offset)
--- @param col_end number 0-indexed end column (byte offset, exclusive)
--- @param hl_group string Highlight group name
function M.apply_col_highlight(buf, row, col_start, col_end, hl_group)
	local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
	if not line then
		return
	end
	local end_col = math.min(col_end, #line)
	if col_start >= end_col then
		return
	end
	vim.api.nvim_buf_set_extmark(buf, M.ns_layout, row, col_start, {
		end_col = end_col,
		hl_group = hl_group,
		priority = 110,
	})
end

--- Place the green target highlight on a character, range, or full line.
--- Clears previous target extmark first.
--- @param buf number Buffer handle
--- @param target_buf_row number 0-indexed buffer row
--- @param target_col number 0-indexed column
--- @param target_end_col number|nil 0-indexed exclusive end column (default: target_col + 1)
--- @param full_line boolean|nil If true, highlight the entire line (for dd)
--- @param hl_group string|nil Highlight group (default: "VimTeacherTarget")
function M.place_target(buf, target_buf_row, target_col, target_end_col, full_line, hl_group)
	hl_group = hl_group or "VimTeacherTarget"
	vim.api.nvim_buf_clear_namespace(buf, M.ns_target, 0, -1)

	local line_count = vim.api.nvim_buf_line_count(buf)
	if target_buf_row >= line_count then
		return
	end

	if full_line then
		local line = vim.api.nvim_buf_get_lines(buf, target_buf_row, target_buf_row + 1, false)[1]
		local opts = {
			line_hl_group = hl_group,
			priority = 200,
		}
		-- For empty lines, add virtual text so the highlight is visible
		if not line or #line == 0 then
			opts.virt_text = { { " ← this line", hl_group } }
			opts.virt_text_pos = "overlay"
		else
			-- Also set character-level highlight so syntax/treesitter can't override
			opts.end_col = #line
			opts.hl_group = hl_group
		end
		vim.api.nvim_buf_set_extmark(buf, M.ns_target, target_buf_row, 0, opts)
		return
	end

	local line = vim.api.nvim_buf_get_lines(buf, target_buf_row, target_buf_row + 1, false)[1]
	if not line or target_col >= #line then
		return
	end

	-- Guard against invalid or zero-width ranges from challenge range computation.
	-- Extmarks with end_col <= start_col are effectively invisible.
	local end_col = target_end_col or (target_col + 1)
	end_col = math.min(end_col, #line)
	if end_col <= target_col then
		end_col = math.min(#line, target_col + 1)
		if end_col <= target_col then
			return
		end
	end

	vim.api.nvim_buf_set_extmark(buf, M.ns_target, target_buf_row, target_col, {
		end_col = end_col,
		hl_group = hl_group,
		priority = 200,
	})
end

--- Place target highlight on multiple full lines.
--- Clears previous target extmarks first.
--- @param buf number Buffer handle
--- @param rows number[] List of 0-indexed buffer rows to highlight
--- @param hl_group string|nil Highlight group (default: "VimTeacherTarget")
function M.place_target_rows(buf, rows, hl_group)
	hl_group = hl_group or "VimTeacherTarget"
	vim.api.nvim_buf_clear_namespace(buf, M.ns_target, 0, -1)

	local line_count = vim.api.nvim_buf_line_count(buf)
	for _, row in ipairs(rows) do
		if row < line_count then
			local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1]
			local opts = {
				line_hl_group = hl_group,
				priority = 200,
			}
			if not line or #line == 0 then
				-- For empty lines, add virtual text so the highlight is visible
				opts.virt_text = { { " ← this line", hl_group } }
				opts.virt_text_pos = "overlay"
			else
				-- Also set character-level highlight so syntax/treesitter can't override
				opts.end_col = #line
				opts.hl_group = hl_group
			end
			vim.api.nvim_buf_set_extmark(buf, M.ns_target, row, 0, opts)
		end
	end
end

--- Place a virtual line marker showing where a yanked line should be pasted.
--- Must be called AFTER place_target_rows (does not clear ns_target).
--- @param buf number Buffer handle
--- @param after_row number 0-indexed buffer row; marker appears below this line
function M.place_paste_marker(buf, after_row)
	local line_count = vim.api.nvim_buf_line_count(buf)
	if after_row >= line_count then
		return
	end
	vim.api.nvim_buf_set_extmark(buf, M.ns_target, after_row, 0, {
		virt_lines = {
			{
				{
					"  ▸ ─── paste the yanked line here ─────────────────────────",
					"VimTeacherInsertHint",
				},
			},
		},
		virt_lines_above = false,
		priority = 200,
	})
end

--- Flash a gold success highlight at the target position.
--- @param buf number Buffer handle
--- @param target_buf_row number 0-indexed buffer row
--- @param target_col number 0-indexed column
function M.flash_success(buf, target_buf_row, target_col)
	vim.api.nvim_buf_clear_namespace(buf, M.ns_target, 0, -1)

	local line_count = vim.api.nvim_buf_line_count(buf)
	if target_buf_row >= line_count then
		return
	end

	local line = vim.api.nvim_buf_get_lines(buf, target_buf_row, target_buf_row + 1, false)[1]
	if not line or target_col >= #line then
		return
	end

	vim.api.nvim_buf_set_extmark(buf, M.ns_target, target_buf_row, target_col, {
		end_col = target_col + 1,
		hl_group = "VimTeacherSuccess",
		priority = 200,
	})
end

--- Clear all extmarks in both namespaces.
--- @param buf number Buffer handle
function M.clear_all(buf)
	if M.ns_layout then
		vim.api.nvim_buf_clear_namespace(buf, M.ns_layout, 0, -1)
	end
	if M.ns_target then
		vim.api.nvim_buf_clear_namespace(buf, M.ns_target, 0, -1)
	end
end

return M
