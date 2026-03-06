-- vimteacher/lessons/pool.lua
-- Shared helpers for challenge-pool lessons.

local optimal = require("vimteacher.optimal")
local recent_picker = require("vimteacher.recent")

local M = {}

--- Build reusable helpers around a fixed challenge pool.
--- @param challenges table[]
--- @param opts table|nil
--- @return table
function M.new(challenges, opts)
	opts = opts or {}
	local recent = {}
	local current_snippet = nil
	local max_recent = opts.max_recent or 5
	local track_current_snippet = opts.track_current_snippet ~= false
	local transform_challenge = opts.transform_challenge

	local function nav_cost(motions)
		return function(lines, start_pos, target)
			return optimal.nav_cost(lines, start_pos, target, motions)
		end
	end

	local function generate_challenge(_buf, _ns_id)
		local idx = recent_picker.pick_avoiding_recent(#challenges, recent, max_recent)
		local raw = challenges[idx]
		local challenge = vim.deepcopy(raw)
		if transform_challenge then
			local transformed = transform_challenge(challenge, raw)
			if transformed ~= nil then
				challenge = transformed
			end
		end
		if track_current_snippet then
			current_snippet = challenge.snippet_lines
		end
		return challenge
	end

	local function nav_compute_optimal(motions)
		local compute_nav = nav_cost(motions)
		return function(start_pos, target)
			if not current_snippet then
				return optimal.manhattan(start_pos, target)
			end
			return compute_nav(current_snippet, start_pos, target)
		end
	end

	return {
		generate_challenge = generate_challenge,
		get_challenges = function()
			return challenges
		end,
		get_current_snippet = function()
			return current_snippet
		end,
		nav_cost = nav_cost,
		nav_compute_optimal = nav_compute_optimal,
	}
end

return M
