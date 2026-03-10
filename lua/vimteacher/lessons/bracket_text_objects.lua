-- vimteacher/lessons/bracket_text_objects.lua
-- Shared factory for bracket-focused text object lessons.

local base = require("vimteacher.lessons.base")
local pool = require("vimteacher.lessons.pool")

local M = {}

--- Build a bracket lesson from shared lesson metadata and a challenge pool.
--- @param opts table
--- @param opts.lesson table Arguments forwarded to base.define
--- @param opts.challenges table[] Static challenge pool
--- @param opts.optimal_offset number|nil Additional moves added after nav scoring
--- @return table
function M.define(opts)
	opts = opts or {}
	local lesson_opts = opts.lesson or {}
	local challenges = opts.challenges or {}
	local optimal_offset = opts.optimal_offset or 0

	local lesson = base.define(lesson_opts)
	local challenge_pool = pool.new(challenges)
	local compute_nav_optimal = challenge_pool.nav_compute_optimal()

	function lesson.compute_optimal(start_pos, target)
		return compute_nav_optimal(start_pos, target) + optimal_offset
	end

	lesson.generate_challenge = challenge_pool.generate_challenge
	lesson._get_challenges = challenge_pool.get_challenges
	return lesson
end

return M
