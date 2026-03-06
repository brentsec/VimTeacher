-- vimteacher/buffer.lua
-- Buffer creation and thin UI facade.

local highlight = require("vimteacher.highlight")
local completion_ui = require("vimteacher.ui.completion")
local lesson_ui = require("vimteacher.ui.lesson")
local menu_ui = require("vimteacher.ui.menu")
local stats_ui = require("vimteacher.ui.stats")

local M = {}

local layout_meta = {
	snippet_offset = 0,
	snippet_end = 0,
	progress_line = nil,
}

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
	menu_ui.render_menu(buf, sections, all_stats, win)
end

--- Render the lesson layout with description, progress bar, and code snippet.
--- @param buf number Buffer handle
--- @param opts table Render options
function M.render(buf, opts)
	layout_meta = lesson_ui.render(buf, opts)
end

--- Render the stats overlay (replaces snippet zone content between challenges).
--- @param buf number Buffer handle
--- @param opts table Stats options
function M.render_challenge_stats(buf, opts)
	stats_ui.render_challenge_stats(buf, opts)
end

--- Render the final completion screen for a lesson with session stats summary.
--- @param buf number Buffer handle
--- @param opts table Completion options
function M.render_completion(buf, opts)
	completion_ui.render_completion(buf, opts)
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
	local line_count = vim.api.nvim_buf_line_count(buf)
	if layout_meta.progress_line < 0 or layout_meta.progress_line >= line_count then
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
