-- tests/test_dwell_config.lua
-- Coverage for lesson dwell-time configuration handling.

local gameplay = require("vimteacher.gameplay")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_dwell_config: running...")

local function new_state(lesson)
	local buf = vim.api.nvim_create_buf(false, true)
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

local function run_cursor_case(lesson, wait_before_assert_ms, wait_after_assert_ms)
	local state = new_state(lesson)
	local advances = 0
	local controller = gameplay.new({
		state = state,
		advance_challenge = function()
			advances = advances + 1
		end,
	})

	controller.on_cursor_moved()
	if wait_before_assert_ms and wait_before_assert_ms > 0 then
		vim.wait(wait_before_assert_ms, function()
			return false
		end, wait_before_assert_ms)
	end
	local before = advances
	if wait_after_assert_ms and wait_after_assert_ms > 0 then
		vim.wait(wait_after_assert_ms, function()
			return advances > before
		end, 5)
	end

	vim.api.nvim_buf_delete(state.buf, { force = true })
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
	vim.wait(10, function()
		return false
	end, 10)

	vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
	controller.on_cursor_moved()
	vim.wait(10, function()
		return false
	end, 10)

	vim.api.nvim_win_set_cursor(state.win, { 1, 1 })
	controller.on_cursor_moved()
	vim.wait(35, function()
		return advances > 0
	end, 5)
	local before_second_dwell = advances
	vim.wait(40, function()
		return advances > before_second_dwell
	end, 5)

	vim.api.nvim_buf_delete(state.buf, { force = true })
	return before_second_dwell, advances
end

local before_default, after_default = run_cursor_case({}, 20, 80)
assert_test(before_default == 0, "default dwell should not advance before the dwell timer elapses")
assert_test(after_default == 1, "default dwell should advance after the dwell timer elapses")

local before_explicit, after_explicit = run_cursor_case({ dwell_time = 5 }, 20, 20)
assert_test(before_explicit == 1, "dwell_time should control the dwell delay")
assert_test(after_explicit == 1, "dwell_time should only advance once")

local before_alias, after_alias = run_cursor_case({ dwell_ms = 0 }, 10, 10)
assert_test(before_alias == 1, "dwell_ms compatibility alias should be accepted")
assert_test(after_alias == 1, "dwell_ms alias should only advance once")

local before_reentry, after_reentry = run_leave_and_return_case()
assert_test(before_reentry == 0, "leaving and re-entering should restart the dwell timer")
assert_test(after_reentry == 1, "re-entering should still advance after the full second dwell")

counter.finish("test_dwell_config")
