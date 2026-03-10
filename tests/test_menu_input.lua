-- tests/test_menu_input.lua
-- Tests for topic menu input behavior.

local input = require("vimteacher.input")
local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_menu_input: running...")

local original_notify = vim.notify
local original_timer_start = vim.fn.timer_start
local original_timer_stop = vim.fn.timer_stop
local original_schedule = vim.schedule
local notify_calls = {}
local timer_callbacks = {}
local scheduled_callbacks = {}
local stopped_timers = {}

vim.notify = function(msg, level)
	notify_calls[#notify_calls + 1] = {
		msg = msg,
		level = level,
	}
end

vim.fn.timer_start = function(_timeout, cb)
	timer_callbacks[#timer_callbacks + 1] = cb
	return #timer_callbacks
end

vim.fn.timer_stop = function(timer_id)
	stopped_timers[timer_id] = true
	return 1
end

vim.schedule = function(cb)
	scheduled_callbacks[#scheduled_callbacks + 1] = cb
end

local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
	"header",
	"lesson one",
	"lesson two",
})

local state = {
	buf = buf,
	win = win,
	mode = "menu",
}

local controller = input.new({
	state = state,
	lessons = {
		get_all = function()
			local lessons = {}
			for i = 1, 12 do
				lessons[#lessons + 1] = {
					name = "lesson_" .. i,
					title = "Lesson " .. i,
				}
			end
			return lessons
		end,
		get_sections = function()
			return {}
		end,
	},
})

local started = nil
local stopped = false
controller.setup_menu_keymaps(function(name)
	started = name
end, function()
	stopped = true
	state.mode = "stopped"
	state.buf = nil
end)

vim.api.nvim_buf_set_var(buf, "vimteacher_menu_row_to_lesson", {
	[3] = 2,
})

local function cleanup()
	controller.clear_menu_keymaps()
	vim.notify = original_notify
	vim.fn.timer_start = original_timer_start
	vim.fn.timer_stop = original_timer_stop
	vim.schedule = original_schedule
	if vim.api.nvim_buf_is_valid(buf) then
		vim.api.nvim_buf_delete(buf, { force = true })
	end
end

local ok, err = xpcall(function()
	vim.api.nvim_win_set_cursor(win, { 3, 0 })
	local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
	vim.api.nvim_feedkeys(enter, "xt", false)
	vim.cmd("redraw")

	assert_test(started == "lesson_2", "Enter on a lesson row should start the highlighted lesson")
	assert_test(stopped == false, "Enter should not stop the session")

	started = nil
	vim.api.nvim_win_set_cursor(win, { 1, 0 })
	vim.api.nvim_feedkeys(enter, "xt", false)
	vim.cmd("redraw")

	assert_test(started == nil, "Enter on a non-lesson row should do nothing")

	started = nil
	local digit_one = vim.api.nvim_replace_termcodes("1", true, false, true)
	local quit = vim.api.nvim_replace_termcodes("q", true, false, true)
	vim.api.nvim_feedkeys(digit_one, "xt", false)
	vim.cmd("redraw")
	assert_test(
		type(timer_callbacks[1]) == "function",
		"digit input should defer a potentially-extendable lesson number"
	)

	vim.api.nvim_feedkeys(quit, "xt", false)
	vim.cmd("redraw")
	assert_test(stopped == true, "q should stop the session from the menu")
	assert_test(stopped_timers[1] == true, "q should stop the pending digit timer")

	timer_callbacks[1]()
	assert_test(type(scheduled_callbacks[1]) == "function", "digit timer should queue its flush on the event loop")
	scheduled_callbacks[1]()
	assert_test(started == nil, "a stale queued digit flush should not start a lesson after q")

	state.mode = "menu"
	state.buf = buf

	controller.rerender_menu_layout(function()
		error("layout boom")
	end)
	assert_test(#notify_calls == 1, "rerender_menu_layout should surface render errors")
	assert_test(
		notify_calls[1].msg:find("failed to rerender the menu layout", 1, true) ~= nil,
		"rerender_menu_layout notifications should include context"
	)
end, debug.traceback)

cleanup()

if not ok then
	error(err)
end

counter.finish("test_menu_input")
