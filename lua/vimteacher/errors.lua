-- vimteacher/errors.lua
-- Shared helpers for surfacing recoverable runtime errors to the user.

local M = {}

function M.report(context, err)
	vim.notify("VimTeacher: " .. context .. ": " .. tostring(err), vim.log.levels.ERROR)
end

function M.call(context, fn, ...)
	local ok, result1, result2, result3, result4 = pcall(fn, ...)
	if not ok then
		M.report(context, result1)
		return false
	end
	return true, result1, result2, result3, result4
end

return M
