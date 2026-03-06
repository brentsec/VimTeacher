-- vimteacher/gameplay.lua
-- Active lesson render + event-loop logic.

local buffer = require("vimteacher.buffer")
local goal = require("vimteacher.goal")
local highlight = require("vimteacher.highlight")
local highlight_plan = require("vimteacher.highlight_plan")
local key_display = require("vimteacher.key_display")
local validate = require("vimteacher.validate")

local M = {}

--- Normalize spaces immediately inside bracket pairs for tolerant matching.
--- Strips whitespace after ( [ { and before ) ] }.
--- @param line string
--- @return string
local function normalize_bracket_spaces(line)
	line = line:gsub("([{%[%(])%s+", "%1")
	line = line:gsub("%s+([}%]%)])", "%1")
	return line
end

local function lines_equal(a, b, normalizer)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		local left = a[i]
		local right = b[i]
		if normalizer then
			left = normalizer(left)
			right = normalizer(right)
		end
		if left ~= right then
			return false
		end
	end
	return true
end

--- Build the gameplay controller around the shared session state.
--- @param deps table
--- @return table
function M.new(deps)
	local state = deps.state
	local controller = {}

	local function build_lesson_view(lesson)
		return key_display.build_lesson_view(lesson, state.key_display)
	end

	local function apply_phase(challenge, phase_idx)
		local phase = challenge and challenge.phases and challenge.phases[phase_idx]
		if not phase then
			return false
		end
		challenge.phase_index = phase_idx
		challenge.target = { row = phase.target.row, col = phase.target.col }
		challenge.key = phase.key
		challenge.char = phase.char
		challenge.goal_text = phase.goal_text
		challenge.target_end_col = phase.target_end_col
		if phase.start_pos then
			challenge.start_pos = { row = phase.start_pos.row, col = phase.start_pos.col }
		end
		challenge.expected_lines = vim.deepcopy(phase.expected_lines or challenge.expected_lines)
		return true
	end

	local function on_target_reached()
		if deps.advance_challenge then
			deps.advance_challenge()
		end
	end

	local function snippet_matches_expected(expected)
		if not expected or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return false
		end
		local actual = vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_offset + #expected, false)

		local match = lines_equal(actual, expected)
		if not match and lines_equal(actual, expected, normalize_bracket_spaces) then
			match = true
		end

		return match
	end

	local function restore_original_snippet()
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end
		if not state.original_snippet or not state.current_challenge then
			return
		end

		local rel_cursor = nil
		if state.win and vim.api.nvim_win_is_valid(state.win) then
			local cur = vim.api.nvim_win_get_cursor(state.win)
			rel_cursor = { row = cur[1] - 1 - state.snippet_offset, col = cur[2] }
		end

		controller.render_current_challenge(rel_cursor)
		vim.notify("Not quite — try again!", vim.log.levels.INFO)
	end

	function controller.render_current_challenge(cursor_rel)
		local challenge = state.current_challenge
		if not challenge then
			return
		end
		local view = state.lesson_view or build_lesson_view(state.lesson)
		local goal_text = challenge.goal_text or view.goal_text
		goal_text = key_display.apply_to_text(goal_text, state.key_display or {})
		local goal_display_key = (state.key_display and state.key_display[challenge.key]) or challenge.key

		state.loading = true

		buffer.render(state.buf, {
			title = view.title,
			description = view.description,
			progress = state.challenge_num,
			max_progress = state.max_challenges,
			snippet_lines = challenge.snippet_lines,
			hint_lines = view.hint_lines,
			goal_text = goal_text,
			goal = goal.build(challenge.key, challenge.char, goal_display_key),
			nav_hint_line = string.format(
				"[%s] Menu  [%s] Restart lesson",
				state.play_menu_key or "q",
				state.play_restart_key or "Q"
			),
		})

		state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()
		state.total_buf_lines = vim.api.nvim_buf_line_count(state.buf)
		state.target = challenge.target

		if challenge.highlight_rows then
			local buf_rows = {}
			for _, r in ipairs(challenge.highlight_rows) do
				buf_rows[#buf_rows + 1] = r + state.snippet_offset
			end
			highlight.place_target_rows(state.buf, buf_rows)
			if challenge.paste_marker_after_row ~= nil then
				highlight.place_paste_marker(state.buf, challenge.paste_marker_after_row + state.snippet_offset)
			end
		else
			challenge._highlight_plan = highlight_plan.compute_for_challenge(challenge)
			local target_buf_row = state.target.row + state.snippet_offset
			local hl_group = challenge.search_word and "VimTeacherSearchTarget" or nil
			local plan = challenge._highlight_plan
			local hl_col = state.target.col
			local target_end_col = nil
			local full_line = false
			if plan then
				hl_col = plan.start_col or hl_col
				target_end_col = plan.end_col
				full_line = plan.full_line
			end
			highlight.place_target(state.buf, target_buf_row, hl_col, target_end_col, full_line, hl_group)
		end

		local desired = cursor_rel or challenge.start_pos or { row = 0, col = 0 }
		local max_row = math.max(0, (#challenge.snippet_lines or 1) - 1)
		local row = math.max(0, math.min(desired.row or 0, max_row))
		local line = challenge.snippet_lines[row + 1] or ""
		local col = math.max(0, math.min(desired.col or 0, #line))
		vim.api.nvim_win_set_cursor(state.win, { row + state.snippet_offset + 1, col })
		state.pending_programmatic_cursor = { row = row + state.snippet_offset + 1, col = col }
		if state.challenge_num == 1 and not cursor_rel then
			vim.fn.winrestview({ topline = 1, leftcol = 0 })
		end

		if state.lesson.type == "insert" then
			state.original_snippet =
				vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_end + 1, false)
			vim.bo[state.buf].modifiable = true
		end

		if state.timer_start and state.challenge_load_time then
			local elapsed = (vim.loop.hrtime() - state.challenge_load_time) / 1e9
			buffer.update_timer(state.buf, elapsed)
		else
			buffer.update_timer(state.buf, 0)
		end

		state.loading = nil
	end

	local function advance_challenge_phase()
		local challenge = state.current_challenge
		if not challenge or not challenge.phases then
			return false
		end

		local current_idx = challenge.phase_index or 1
		local next_idx = current_idx + 1
		if not challenge.phases[next_idx] then
			return false
		end

		local cursor = vim.api.nvim_win_get_cursor(state.win)
		local rel_cursor = { row = cursor[1] - 1 - state.snippet_offset, col = cursor[2] }
		challenge.snippet_lines = vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_end + 1, false)
		if not apply_phase(challenge, next_idx) then
			return false
		end
		challenge._highlight_plan = nil
		controller.render_current_challenge(rel_cursor)
		return true
	end

	function controller.on_insert_leave()
		if state.mode ~= "playing" then
			return
		end
		if not state.lesson or state.lesson.type ~= "insert" then
			return
		end
		if not state.current_challenge or not state.current_challenge.expected_lines then
			return
		end
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end

		if snippet_matches_expected(state.current_challenge.expected_lines) then
			if not advance_challenge_phase() then
				on_target_reached()
			end
		else
			restore_original_snippet()
		end
	end

	local function macro_session_busy()
		return vim.fn.reg_recording() ~= "" or vim.fn.reg_executing() ~= ""
	end

	local function schedule_insert_validation_retry()
		if state.insert_validate_timer then
			return
		end
		state.insert_validate_timer = vim.fn.timer_start(25, function()
			state.insert_validate_timer = nil
			vim.schedule(function()
				if state.mode ~= "playing" then
					return
				end
				if not state.lesson or state.lesson.type ~= "insert" then
					return
				end
				if not state.lesson.allowed_modify_keys then
					return
				end
				if macro_session_busy() then
					local busy_ms = state.insert_busy_since and ((vim.loop.hrtime() - state.insert_busy_since) / 1e6) or 0
					if busy_ms >= 150 and snippet_matches_expected(state.current_challenge.expected_lines) then
						state.insert_busy_since = nil
						if not advance_challenge_phase() then
							on_target_reached()
						end
						return
					end
					schedule_insert_validation_retry()
					return
				end
				controller.on_text_changed()
			end)
		end)
	end

	function controller.on_text_changed()
		if state.mode ~= "playing" then
			return
		end
		if state.loading then
			return
		end
		if not state.lesson or state.lesson.type ~= "insert" then
			return
		end
		if not state.lesson.allowed_modify_keys then
			return
		end
		if not state.current_challenge or not state.current_challenge.expected_lines then
			return
		end
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end
		if macro_session_busy() then
			if not state.insert_busy_since then
				state.insert_busy_since = vim.loop.hrtime()
			end

			local busy_ms = (vim.loop.hrtime() - state.insert_busy_since) / 1e6
			if busy_ms >= 150 and snippet_matches_expected(state.current_challenge.expected_lines) then
				state.insert_busy_since = nil
				if not advance_challenge_phase() then
					on_target_reached()
				end
				return
			end

			schedule_insert_validation_retry()
			return
		end
		state.insert_busy_since = nil

		if snippet_matches_expected(state.current_challenge.expected_lines) then
			if not advance_challenge_phase() then
				on_target_reached()
			end
			return
		end

		local orig = state.original_snippet
		local actual = vim.api.nvim_buf_get_lines(
			state.buf,
			state.snippet_offset,
			state.snippet_offset + #(state.current_challenge.expected_lines or {}),
			false
		)
		if orig and lines_equal(actual, orig) then
			return
		end

		restore_original_snippet()
	end

	local function is_on_target()
		local target_buf_row = state.target.row + state.snippet_offset
		if state.current_challenge and state.current_challenge.row_only_check then
			local cursor = vim.api.nvim_win_get_cursor(state.win)
			return (cursor[1] - 1) == target_buf_row
		end
		return validate.check_position(state.win, target_buf_row, state.target.col)
	end

	function controller.on_cursor_moved()
		if state.mode == "info" then
			validate.constrain_to_snippet(state.win, state.snippet_offset, state.snippet_end)
			return
		end

		if state.mode ~= "playing" then
			return
		end
		if state.loading then
			return
		end
		if not state.target then
			return
		end
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end
		if not state.win or not vim.api.nvim_win_is_valid(state.win) then
			return
		end

		if state.pending_programmatic_cursor then
			local cur = vim.api.nvim_win_get_cursor(state.win)
			local p = state.pending_programmatic_cursor
			state.pending_programmatic_cursor = nil
			if cur[1] == p.row and cur[2] == p.col then
				return
			end
		end

		local was_constrained = validate.constrain_to_snippet(state.win, state.snippet_offset, state.snippet_end)
		if was_constrained then
			if state.lesson and state.lesson.type ~= "insert" and is_on_target() then
				state.move_count = state.move_count + 1
				on_target_reached()
			end
			return
		end

		state.move_count = state.move_count + 1
		if state.lesson and state.lesson.type == "insert" then
			return
		end

		if is_on_target() then
			if not state.dwell_pending then
				state.dwell_pending = true
				vim.defer_fn(function()
					state.dwell_pending = false
					if state.mode ~= "playing" then
						return
					end
					if not state.target then
						return
					end
					if not state.win or not vim.api.nvim_win_is_valid(state.win) then
						return
					end
					if is_on_target() then
						on_target_reached()
					end
				end, state.lesson.dwell_time or 50)
			end
		else
			state.dwell_pending = false
		end
	end

	function controller.setup_autocmds()
		state.augroup = vim.api.nvim_create_augroup("VimTeacher", { clear = true })

		vim.api.nvim_create_autocmd("CursorMoved", {
			group = state.augroup,
			buffer = state.buf,
			callback = controller.on_cursor_moved,
		})

		vim.api.nvim_create_autocmd("InsertLeave", {
			group = state.augroup,
			buffer = state.buf,
			callback = controller.on_insert_leave,
		})

		vim.api.nvim_create_autocmd("TextChanged", {
			group = state.augroup,
			buffer = state.buf,
			callback = controller.on_text_changed,
		})

		vim.api.nvim_create_autocmd("ModeChanged", {
			group = state.augroup,
			pattern = "[vV\x16]*:n*",
			callback = function()
				if vim.api.nvim_get_current_buf() ~= state.buf then
					return
				end
				vim.schedule(controller.on_text_changed)
			end,
		})

		vim.api.nvim_create_autocmd("BufWipeout", {
			group = state.augroup,
			buffer = state.buf,
			callback = function()
				if deps.cleanup then
					deps.cleanup()
				end
			end,
		})

		vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
			group = state.augroup,
			callback = function()
				if deps.rerender_menu_layout then
					deps.rerender_menu_layout()
				end
			end,
		})
	end

	controller.apply_phase = apply_phase
	controller.build_lesson_view = build_lesson_view
	controller.normalize_bracket_spaces = normalize_bracket_spaces

	return controller
end

return M
