-- vimteacher/state.lua
-- Shared session state for the active VimTeacher instance.

local M = {}
local next_session_generation = 0
local next_challenge_generation = 0

local function initial_state()
	return {
		buf = nil,
		win = nil,
		augroup = nil,
		lesson = nil,
		lesson_name = nil,
		challenge_num = 0,
		max_challenges = 10,
		target = nil,
		snippet_offset = 0,
		snippet_end = 0,
		move_count = 0,
		timer_start = nil,
		optimal_moves = 0,
		all_stats = {},
		mode = "menu",
		current_challenge = nil,
		session_challenges = {},
		dwell_pending = false,
		original_snippet = nil,
		total_buf_lines = nil,
		elapsed_timer = nil,
		insert_validate_timer = nil,
		insert_busy_since = nil,
		challenge_load_time = nil,
		pending_programmatic_cursor = nil,
		last_cursor = nil,
		saved_inccommand = nil,
		source_window_line_numbers = nil,
		preferred_lesson_line_numbers = nil,
		play_menu_key = "q",
		play_restart_key = "Q",
		config = nil,
		key_display = nil,
		lesson_view = nil,
		loading = nil,
		session_generation = 0,
		challenge_generation = 0,
		dwell_generation = 0,
	}
end

local state = initial_state()

M.session = state

--- Transition the active session mode.
--- @param from string|nil Expected current mode, or nil to skip the check
--- @param to string Next mode
--- @return boolean
function M.transition(from, to)
	if from ~= nil and state.mode ~= from then
		return false
	end
	state.mode = to
	return true
end

--- Advance the session generation to invalidate stale async callbacks.
--- @return number
function M.bump_session_generation()
	next_session_generation = next_session_generation + 1
	state.session_generation = next_session_generation
	return state.session_generation
end

--- Advance the challenge generation to invalidate stale per-challenge callbacks.
--- @return number
function M.bump_challenge_generation()
	next_challenge_generation = next_challenge_generation + 1
	state.challenge_generation = next_challenge_generation
	state.dwell_generation = 0
	return state.challenge_generation
end

--- Reset the active session state back to defaults.
function M.reset()
	for key in pairs(state) do
		state[key] = nil
	end

	local defaults = initial_state()
	for key, value in pairs(defaults) do
		if type(value) == "table" then
			state[key] = vim.deepcopy(value)
		else
			state[key] = value
		end
	end
end

return M
