-- vimteacher/session.lua
-- Session lifecycle helpers for the active VimTeacher run.

local buffer = require("vimteacher.buffer")
local highlight = require("vimteacher.highlight")
local key_blocking = require("vimteacher.key_blocking")
local lessons = require("vimteacher.lessons")
local snippets = require("vimteacher.snippets")
local state_mod = require("vimteacher.state")
local stats_mod = require("vimteacher.stats")

local M = {}

--- Build a session controller around the shared plugin dependencies.
--- @param deps table|nil
--- @return table
function M.new(deps)
	deps = deps or {}
	local state = deps.state or state_mod.session
	local gameplay = deps.gameplay or {}
	local mode_keymaps = deps.mode_keymaps or {}
	local menu = deps.menu or {}
	local controller = {}

	local function stop_elapsed_timer()
		if state.elapsed_timer then
			vim.fn.timer_stop(state.elapsed_timer)
			state.elapsed_timer = nil
		end
	end

	local function update_timer_display()
		if not state.challenge_load_time then
			return
		end
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end
		local elapsed = (vim.loop.hrtime() - state.challenge_load_time) / 1e9
		buffer.update_timer(state.buf, elapsed)
	end

	local function start_elapsed_timer()
		stop_elapsed_timer()
		state.challenge_load_time = vim.loop.hrtime()
		state.elapsed_timer = vim.fn.timer_start(1000, function()
			vim.schedule(update_timer_display)
		end, { ["repeat"] = -1 })
	end

	function controller.stop()
		stop_elapsed_timer()
		if state.insert_validate_timer then
			vim.fn.timer_stop(state.insert_validate_timer)
			state.insert_validate_timer = nil
		end

		if state.augroup then
			pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
			state.augroup = nil
		end

		if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
			pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
		end

		if state.saved_inccommand ~= nil then
			vim.o.inccommand = state.saved_inccommand
		end
		state_mod.reset()
	end

	function controller.show_menu()
		stop_elapsed_timer()
		state_mod.transition(nil, "menu")
		state.target = nil
		if mode_keymaps.clear_info_keymaps then
			mode_keymaps.clear_info_keymaps()
		end
		if mode_keymaps.clear_playing_keymaps then
			mode_keymaps.clear_playing_keymaps()
		end

		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			state.buf, state.win = buffer.create()
			if gameplay.setup_autocmds then
				gameplay.setup_autocmds()
			end
			key_blocking.block_insert_keys(state.buf)
		end

		local all_sections = lessons.get_sections()
		local ok = pcall(buffer.render_menu, state.buf, all_sections, state.all_stats, state.win)
		if not ok then
			return
		end
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.fn.winrestview({ topline = 1, leftcol = 0 })
			vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
		end
		if menu.setup then
			menu.setup()
		end
	end

	function controller.advance_challenge()
		stop_elapsed_timer()

		local elapsed = 0
		if state.timer_start then
			elapsed = (vim.loop.hrtime() - state.timer_start) / 1e9
		end

		local scored_optimal = stats_mod.normalize_optimal_moves(state.optimal_moves, state.move_count)
		local accuracy_pct = stats_mod.calc_accuracy_pct(scored_optimal, state.move_count)
		state.session_challenges[#state.session_challenges + 1] = {
			time = elapsed,
			accuracy_pct = accuracy_pct,
			moves = state.move_count,
			optimal = scored_optimal,
		}

		local target_buf_row = state.target.row + state.snippet_offset
		highlight.flash_success(state.buf, target_buf_row, state.target.col)

		state.target = nil
		state_mod.transition("playing", "stats")

		vim.defer_fn(function()
			if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
				return
			end

			if state.challenge_num >= state.max_challenges then
				local total_time = 0
				local total_moves = 0
				local total_optimal = 0
				for _, challenge in ipairs(state.session_challenges) do
					total_time = total_time + challenge.time
					total_moves = total_moves + challenge.moves
					total_optimal = total_optimal + challenge.optimal
				end
				local overall_accuracy = stats_mod.calc_overall_accuracy_pct(total_optimal, total_moves)
				local lesson_stats = stats_mod.record_session(state.all_stats, state.lesson_name, total_time, overall_accuracy)
				stats_mod.save(state.all_stats)

				state_mod.transition("stats", "complete")
				buffer.render_completion(state.buf, {
					title = state.lesson.title,
					max_challenges = state.max_challenges,
					session_challenges = state.session_challenges,
					best_time = lesson_stats.best_time,
					avg_time = lesson_stats.avg_time,
				})
				if mode_keymaps.setup_completion_keymaps then
					mode_keymaps.setup_completion_keymaps(controller.start, controller.show_menu, controller.stop)
				end
			else
				controller.load_challenge()
			end
		end, 300)
	end

	function controller.load_challenge()
		state.challenge_num = state.challenge_num + 1
		state_mod.transition(nil, "playing")
		state.move_count = 0
		state.dwell_pending = false

		local challenge = state.lesson.generate_challenge(state.buf, highlight.ns_target)
		if challenge.phases and gameplay.apply_phase then
			gameplay.apply_phase(challenge, 1)
		end
		state.current_challenge = challenge
		state.timer_start = vim.loop.hrtime()
		start_elapsed_timer()

		local start = challenge.start_pos or { row = 0, col = 0 }
		if state.lesson.compute_optimal then
			state.optimal_moves = state.lesson.compute_optimal(start, challenge.target, challenge)
		else
			state.optimal_moves = math.abs(start.row - challenge.target.row) + math.abs(start.col - challenge.target.col)
		end

		if gameplay.render_current_challenge then
			gameplay.render_current_challenge()
		end
	end

	function controller.start(lesson_name)
		if state.buf and vim.api.nvim_buf_is_valid(state.buf) and mode_keymaps.clear_mode_keymaps then
			mode_keymaps.clear_mode_keymaps(menu.clear)
		end

		local lesson = lessons.get_lesson(lesson_name)
		if not lesson then
			vim.notify("VimTeacher: Unknown lesson '" .. lesson_name .. "'", vim.log.levels.ERROR)
			return
		end

		math.randomseed(os.time() + math.floor(os.clock() * 1000))
		snippets.reset_recent()

		state.lesson = lesson
		state.lesson_name = lesson_name
		state.challenge_num = 0
		state.max_challenges = lesson.challenges_required or 10
		state.session_challenges = {}
		state_mod.transition(nil, "playing")
		state.play_menu_key = lesson.play_menu_key or "q"
		state.play_restart_key = lesson.play_restart_key or "Q"
		state.lesson_view = gameplay.build_lesson_view and gameplay.build_lesson_view(lesson) or nil

		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			state.buf, state.win = buffer.create()
			if gameplay.setup_autocmds then
				gameplay.setup_autocmds()
			end
		end

		local nav_opts = { buffer = state.buf, noremap = true, silent = true }
		local top_jump_key = (state.key_display and state.key_display["gg"]) or "gg"
		local bottom_jump_key = (state.key_display and state.key_display["G"]) or "G"
		for _, key in ipairs({ "gg", top_jump_key }) do
			pcall(vim.keymap.del, "n", key, { buffer = state.buf })
		end
		for _, key in ipairs({ "G", bottom_jump_key }) do
			pcall(vim.keymap.del, "n", key, { buffer = state.buf })
		end
		vim.keymap.set("n", top_jump_key, function()
			if state.snippet_offset and state.win and vim.api.nvim_win_is_valid(state.win) then
				vim.api.nvim_win_set_cursor(state.win, { state.snippet_offset + 1, 0 })
			end
		end, nav_opts)
		vim.keymap.set("n", bottom_jump_key, function()
			if state.snippet_end and state.win and vim.api.nvim_win_is_valid(state.win) then
				vim.api.nvim_win_set_cursor(state.win, { state.snippet_end + 1, 0 })
			end
		end, nav_opts)

		if lesson.type == "info" then
			state_mod.transition(nil, "info")
			local info_exempt_keys = key_blocking.resolve_keys_for_lesson(lesson, state.key_display)
			info_exempt_keys[#info_exempt_keys + 1] = "i"
			local resolved_insert = (state.key_display and state.key_display["i"]) or nil
			if type(resolved_insert) == "string" and resolved_insert ~= "" then
				info_exempt_keys[#info_exempt_keys + 1] = resolved_insert
			end
			key_blocking.block_insert_keys(state.buf, info_exempt_keys)
			if lesson.sandbox_modify_keys then
				local sandbox_keys = key_blocking.resolve_keys(state.key_display, lesson.sandbox_modify_keys)
				for _, key in ipairs(sandbox_keys) do
					pcall(vim.keymap.del, "n", key, { buffer = state.buf })
				end
			end
			buffer.render(state.buf, {
				title = state.lesson_view.title,
				description = state.lesson_view.description,
				snippet_lines = state.lesson_view.sandbox_snippet or lesson.sandbox_snippet,
				hint_lines = state.lesson_view.hint_lines,
			})
			state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()
			vim.bo[state.buf].modifiable = true
			vim.bo[state.buf].undolevels = 1000
			local info_start_row = math.min(vim.api.nvim_buf_line_count(state.buf), 3)
			vim.api.nvim_win_set_cursor(state.win, { info_start_row, 0 })
			vim.fn.winrestview({ topline = 1, leftcol = 0 })
			local opts = { buffer = state.buf, noremap = true, silent = true }
			vim.keymap.set("n", "n", function()
				local next_name = lessons.get_next(lesson_name)
				if next_name then
					controller.start(next_name)
				end
			end, opts)
			vim.keymap.set("n", "q", function()
				controller.show_menu()
			end, opts)
			return
		end

		if lesson.type == "insert" then
			key_blocking.block_keys_for_insert_lesson(
				state.buf,
				key_blocking.resolve_keys(state.key_display, lesson.allowed_keys or {}),
				key_blocking.resolve_keys(state.key_display, lesson.allowed_modify_keys),
				key_blocking.resolve_keys(state.key_display, lesson.allowed_visual_keys)
			)
			vim.bo[state.buf].autoindent = true
		else
			key_blocking.block_insert_keys(state.buf, key_blocking.resolve_keys_for_lesson(lesson, state.key_display))
		end

		if mode_keymaps.setup_playing_keymaps then
			mode_keymaps.setup_playing_keymaps(controller.show_menu, controller.start)
		end
		controller.load_challenge()
	end

	controller.start_elapsed_timer = start_elapsed_timer
	controller.stop_elapsed_timer = stop_elapsed_timer

	return controller
end

return M
