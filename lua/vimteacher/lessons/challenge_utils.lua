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

--- Retry a challenge builder a bounded number of times before failing loudly.
--- @param lesson_name string
--- @param build fun(attempt:number, max_attempts:number):table|nil
--- @param opts table|nil
--- @return table
function M.generate_with_retries(lesson_name, build, opts)
	opts = opts or {}
	local max_attempts = opts.max_attempts or 32

	for attempt = 1, max_attempts do
		local challenge = build(attempt, max_attempts)
		if challenge ~= nil then
			return challenge
		end
	end

	error(string.format("VimTeacher: failed to generate challenge for %s after %d attempts", lesson_name, max_attempts))
end

return M
