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

local function new_state(lesson)
	local buf = vim.api.nvim_create_buf(false, true)
	created_buffers[#created_buffers + 1] = buf
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "ab" })
	vim.api.nvim_win_set_cursor(win, { 1, 1 })

	return {
		mode = "playing",
		lesson = lesson,
		target = { row = 0, col = 1 },
		buf = buf,
		win = win,
		snippet_offset = 0,
		snippet_end = 0,
		move_count = 0,
		dwell_pending = false,
		last_cursor = { 1, 0 },
	}
end

local function run_cursor_case(lesson, run_before_assert, run_after_assert)
	local state = new_state(lesson)
	local advances = 0
	local controller = gameplay.new({
		state = state,
		advance_challenge = function()
			advances = advances + 1
		end,
	})

	controller.on_cursor_moved()
	if type(run_before_assert) == "function" then
		run_before_assert()
	end
	local before = advances
	if type(run_after_assert) == "function" then
		run_after_assert()
	end

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return before, advances
end

local function run_leave_and_return_case()
	local state = new_state({})
	local advances = 0
	local controller = gameplay.new({
		state = state,
		advance_challenge = function()
			advances = advances + 1
		end,
	})

	controller.on_cursor_moved()

	vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
	controller.on_cursor_moved()

	vim.api.nvim_win_set_cursor(state.win, { 1, 1 })
	controller.on_cursor_moved()
	run_deferred(1)
	local before_second_dwell = advances
	run_deferred(2)

	vim.api.nvim_buf_delete(state.buf, { force = true })
	deferred = {}
	return before_second_dwell, advances
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
end, debug.traceback)

cleanup()

if not ok then
	error(err)
end

counter.finish("test_dwell_config")
