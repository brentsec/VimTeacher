-- tests/test_dwell_config.lua
-- Coverage for lesson dwell-time configuration handling.

local gameplay = require("vimteacher.gameplay")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_dwell_config: running...")

local original_defer_fn = vim.defer_fn
local deferred = {}
local created_buffers = {}

local function cleanup()
	vim.defer_fn = original_defer_fn
	deferred = {}
	for _, buf in ipairs(created_buffers) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end
end

local function run_deferred(index)
	local cb = deferred[index]
	if cb then
		cb()
	end
end

local function new_state(lesson, opts)
	opts = opts or {}
	local buf = vim.api.nvim_create_buf(false, true)
	created_buffers[#created_buffers + 1] = buf
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, opts.lines or { "ab" })
	vim.api.nvim_win_set_cursor(win, opts.cursor or { 1, 1 })

	return {
		mode = opts.mode or "playing",
		lesson = lesson,
		target = opts.target or { row = 0, col = 1 },
		buf = buf,
		win = win,
		snippet_offset = opts.snippet_offset or 0,
		snippet_end = opts.snippet_end or 0,
		move_count = 0,
		dwell_pending = false,
		last_cursor = opts.last_cursor or { 1, 0 },
		pending_programmatic_cursor = opts.pending_programmatic_cursor,
		session_generation = opts.session_generation or 1,
		challenge_generation = opts.challenge_generation or 1,
		dwell_generation = opts.dwell_generation or 0,
	}
end

local function build_controller(state)
	local advances = 0
	local timings = 0
	local controller = gameplay.new({
		state = state,
		advance_challenge = function()
			advances = advances + 1
		end,
		begin_challenge_timing = function()
			timings = timings + 1
		end,
	})
	return controller, function()
		return advances
	end, function()
		return timings
	end
end

local function run_cursor_case(lesson, run_before_assert, run_after_assert)
	local state = new_state(lesson)
	local controller, get_advances = build_controller(state)

	controller.on_cursor_moved()
	if type(run_before_assert) == "function" then
		run_before_assert()
	end
	local before = get_advances()
	if type(run_after_assert) == "function" then
		run_after_assert()
	end

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return before, get_advances()
end

local function run_leave_and_return_case()
	local state = new_state({})
	local controller, get_advances = build_controller(state)

	controller.on_cursor_moved()

	vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
	controller.on_cursor_moved()

	vim.api.nvim_win_set_cursor(state.win, { 1, 1 })
	controller.on_cursor_moved()
	run_deferred(1)
	local before_second_dwell = get_advances()
	run_deferred(2)

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return before_second_dwell, get_advances()
end

local function run_programmatic_cursor_case()
	local state = new_state({}, {
		pending_programmatic_cursor = { row = 1, col = 1 },
	})
	local controller, get_advances, get_timings = build_controller(state)

	controller.on_cursor_moved()

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return {
		advances = get_advances(),
		timings = get_timings(),
		move_count = state.move_count,
		pending_programmatic_cursor = state.pending_programmatic_cursor,
		deferred_count = #deferred,
	}
end

local function run_unchanged_cursor_case()
	local state = new_state({}, {
		last_cursor = { 1, 1 },
	})
	local controller, get_advances, get_timings = build_controller(state)

	controller.on_cursor_moved()

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return {
		advances = get_advances(),
		timings = get_timings(),
		move_count = state.move_count,
		deferred_count = #deferred,
	}
end

local function run_constrained_target_case()
	local state = new_state({}, {
		lines = { "header", "ab" },
		cursor = { 1, 1 },
		snippet_offset = 1,
		snippet_end = 1,
		target = { row = 0, col = 1 },
		last_cursor = { 1, 0 },
	})
	local controller, get_advances, get_timings = build_controller(state)

	controller.on_cursor_moved()

	local cursor = vim.api.nvim_win_get_cursor(state.win)
	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return {
		advances = get_advances(),
		timings = get_timings(),
		move_count = state.move_count,
		cursor = cursor,
		deferred_count = #deferred,
	}
end

local function run_insert_cursor_case()
	local state = new_state({ type = "insert" })
	local controller, get_advances, get_timings = build_controller(state)

	controller.on_cursor_moved()

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return {
		advances = get_advances(),
		timings = get_timings(),
		move_count = state.move_count,
		deferred_count = #deferred,
	}
end

local ok, err = xpcall(function()
	vim.defer_fn = function(cb, _ms)
		deferred[#deferred + 1] = cb
		return #deferred
	end

	local before_default, after_default = run_cursor_case({}, nil, function()
		run_deferred(1)
	end)
	assert_test(before_default == 0, "default dwell should not advance before the dwell timer elapses")
	assert_test(after_default == 1, "default dwell should advance after the dwell timer elapses")

	local before_explicit, after_explicit = run_cursor_case({ dwell_time = 5 }, function()
		run_deferred(1)
	end)
	assert_test(before_explicit == 1, "dwell_time should control the dwell delay")
	assert_test(after_explicit == 1, "dwell_time should only advance once")

	local before_alias, after_alias = run_cursor_case({ dwell_ms = 0 }, function()
		run_deferred(1)
	end)
	assert_test(before_alias == 1, "dwell_ms compatibility alias should be accepted")
	assert_test(after_alias == 1, "dwell_ms alias should only advance once")

	local before_reentry, after_reentry = run_leave_and_return_case()
	assert_test(before_reentry == 0, "leaving and re-entering should restart the dwell timer")
	assert_test(after_reentry == 1, "re-entering should still advance after the full second dwell")

	local programmatic = run_programmatic_cursor_case()
	assert_test(programmatic.advances == 0, "programmatic cursor moves should not advance the challenge")
	assert_test(programmatic.timings == 0, "programmatic cursor moves should not start timing")
	assert_test(programmatic.move_count == 0, "programmatic cursor moves should not increment move_count")
	assert_test(
		programmatic.pending_programmatic_cursor == nil,
		"programmatic cursor suppression should clear the pending cursor marker"
	)
	assert_test(programmatic.deferred_count == 0, "programmatic cursor moves should not schedule dwell callbacks")

	local unchanged = run_unchanged_cursor_case()
	assert_test(unchanged.advances == 0, "unchanged cursor events should not advance the challenge")
	assert_test(unchanged.timings == 0, "unchanged cursor events should not start timing")
	assert_test(unchanged.move_count == 0, "unchanged cursor events should not increment move_count")
	assert_test(unchanged.deferred_count == 0, "unchanged cursor events should not schedule dwell callbacks")

	local constrained = run_constrained_target_case()
	assert_test(constrained.advances == 1, "constrained moves onto the target should advance immediately")
	assert_test(constrained.timings == 1, "constrained moves should still begin challenge timing")
	assert_test(constrained.move_count == 1, "constrained moves onto the target should increment move_count once")
	assert_test(
		constrained.cursor[1] == 2 and constrained.cursor[2] == 1,
		"constrained moves should clamp the cursor into the snippet at the expected target column"
	)
	assert_test(constrained.deferred_count == 0, "constrained moves should not schedule dwell callbacks")

	local insert_case = run_insert_cursor_case()
	assert_test(insert_case.advances == 0, "insert lessons should not advance on cursor movement alone")
	assert_test(insert_case.timings == 1, "insert lessons should still begin timing on the first cursor move")
	assert_test(insert_case.move_count == 1, "insert lessons should still count cursor moves")
	assert_test(insert_case.deferred_count == 0, "insert lessons should not schedule dwell callbacks")
end, debug.traceback)

cleanup()

if not ok then
	error(err)
end

counter.finish("test_dwell_config")
