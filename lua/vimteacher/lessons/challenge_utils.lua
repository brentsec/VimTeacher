-- vimteacher/lessons/challenge_utils.lua
-- Small helpers shared by lesson challenge builders.

local M = {}

--- Find the nth plain-text occurrence of a substring.
--- @param line string
--- @param needle string
--- @param occurrence number|nil
--- @return number|nil 1-indexed byte position
function M.find_nth(line, needle, occurrence)
	local from = 1
	local occ = occurrence or 1
	for i = 1, occ do
		local s, e = line:find(needle, from, true)
		if not s then
			return nil
		end
		if i == occ then
			return s
		end
		from = e + 1
	end
	return nil
end

return M
