-- vimteacher/ui/common.lua
-- Shared UI rendering primitives and constants.

local M = {}

M.SEPARATOR = string.rep("─", 68)

-- ASCII art logo: heavy blocks for "Vim", box-drawing for "Teacher"
M.LOGO = {
	"  ██╗   ██╗██╗███╗   ███╗",
	"  ██║   ██║██║████╗ ████║  ╔╦╗╔═╗╔═╗╔═╗╦ ╦╔═╗╦═╗",
	"  ╚██╗ ██╔╝██║██╔████╔██║   ║ ║╣ ╠═╣║  ╠═╣║╣ ╠╦╝",
	"   ╚████╔╝ ██║██║╚██╔╝██║   ╩ ╚═╝╩ ╩╚═╝╩ ╩╚═╝╩╚═",
	"    ╚═══╝  ╚═╝╚═╝     ╚═╝",
}

--- Truncate a string to max display width.
--- @param s string
--- @param width number
--- @return string
function M.truncate_to_width(s, width)
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
function M.as_text(v)
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
function M.pad_to_width(s, width)
	if width <= 0 then
		return ""
	end
	local display_width = vim.api.nvim_strwidth(s)
	if display_width >= width then
		return M.truncate_to_width(s, width)
	end
	return s .. string.rep(" ", width - display_width)
end

return M
