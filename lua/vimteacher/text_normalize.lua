-- vimteacher/text_normalize.lua
-- Focused text normalization helpers shared across gameplay and tests.

local M = {}

--- Normalize spaces immediately inside bracket pairs for tolerant matching.
--- Strips whitespace after ( [ { and before ) ] }.
--- @param line string
--- @return string
function M.normalize_bracket_spaces(line)
	line = line:gsub("([{%[%(])%s+", "%1")
	line = line:gsub("%s+([}%]%)])", "%1")
	return line
end

return M
