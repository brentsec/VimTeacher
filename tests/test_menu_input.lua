-- tests/test_menu_input.lua
-- Tests for topic menu input behavior.

local input = require("vimteacher.input")
local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_menu_input: running...")

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
}

local controller = input.new({
	state = state,
	lessons = {
		get_all = function()
			return {
				{ name = "intro_modes", title = "Intro to Modes" },
				{ name = "basic_movement", title = "Basic Movement" },
			}
		end,
	},
})

local started = nil
local stopped = false
controller.setup_menu_keymaps(function(name)
	started = name
end, function()
	stopped = true
end)

vim.api.nvim_buf_set_var(buf, "vimteacher_menu_row_to_lesson", {
	[3] = 2,
})

vim.api.nvim_win_set_cursor(win, { 3, 0 })
local enter = vim.api.nvim_replace_termcodes("<CR>", true, false, true)
vim.api.nvim_feedkeys(enter, "xt", false)
vim.cmd("redraw")

assert_test(started == "basic_movement", "Enter on a lesson row should start the highlighted lesson")
assert_test(stopped == false, "Enter should not stop the session")

started = nil
vim.api.nvim_win_set_cursor(win, { 1, 0 })
vim.api.nvim_feedkeys(enter, "xt", false)
vim.cmd("redraw")

assert_test(started == nil, "Enter on a non-lesson row should do nothing")

controller.clear_menu_keymaps()

counter.finish("test_menu_input")
