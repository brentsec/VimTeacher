-- vimteacher/text_class.lua
-- Shared character classification helpers for Vim-style word motions.

local M = {}

--- Classify a character as word-class, punctuation-class, or space.
--- Vim treats keyword chars ([%w_]) as one class, non-blank non-keyword as another.
--- @param char string|nil Single character
--- @return string "word", "punct", or "space"
function M.char_class(char)
	if not char or char == "" or char:match("%s") then
		return "space"
	elseif char:match("[%w_]") then
		return "word"
	else
		return "punct"
	end
end

return M
