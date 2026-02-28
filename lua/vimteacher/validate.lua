-- vimteacher/validate.lua
-- Cursor position checking and snippet region constraining

local M = {}

--- Check if the cursor is at the target position.
--- @param win number Window handle
--- @param target_buf_row number 0-indexed buffer row of target
--- @param target_col number 0-indexed column of target
--- @return boolean True if cursor is on the target
function M.check_position(win, target_buf_row, target_col)
	local cursor = vim.api.nvim_win_get_cursor(win) -- {1-indexed row, 0-indexed col}
	return (cursor[1] - 1) == target_buf_row and cursor[2] == target_col
end

--- Constrain cursor to the snippet zone.
--- If the cursor is outside the zone, move it back inside.
--- @param win number Window handle
--- @param snippet_start number 0-indexed first line of snippet zone
--- @param snippet_end number 0-indexed last line of snippet zone
--- @return boolean True if cursor was constrained (moved)
function M.constrain_to_snippet(win, snippet_start, snippet_end)
	local cursor = vim.api.nvim_win_get_cursor(win) -- {1-indexed row, 0-indexed col}
	local cur_row_0 = cursor[1] - 1
	local cur_col = cursor[2]

	if cur_row_0 < snippet_start then
		vim.api.nvim_win_set_cursor(win, { snippet_start + 1, cur_col })
		return true
	end

	if cur_row_0 > snippet_end then
		vim.api.nvim_win_set_cursor(win, { snippet_end + 1, cur_col })
		return true
	end

	-- Clamp column to line length
	local buf = vim.api.nvim_win_get_buf(win)
	local lines = vim.api.nvim_buf_get_lines(buf, cur_row_0, cur_row_0 + 1, false)
	if lines[1] and #lines[1] > 0 and cur_col >= #lines[1] then
		vim.api.nvim_win_set_cursor(win, { cursor[1], #lines[1] - 1 })
		return true
	end

	return false
end

return M
