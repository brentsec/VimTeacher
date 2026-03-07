-- tests/test_buffer.lua
-- Direct coverage for the lesson buffer facade.

local buffer = require("vimteacher.buffer")
local highlight = require("vimteacher.highlight")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_buffer: running...")

highlight.setup()

local buf, win = buffer.create()
assert_test(vim.api.nvim_buf_is_valid(buf), "create should return a valid buffer")
assert_test(vim.api.nvim_win_is_valid(win), "create should return a valid window")
assert_test(vim.bo[buf].buftype == "nofile", "create should configure a scratch buffer")
assert_test(vim.bo[buf].bufhidden == "wipe", "create should wipe the scratch buffer when hidden")
assert_test(vim.bo[buf].filetype == "vimteacher", "create should mark the buffer as vimteacher")
assert_test(vim.wo[win].signcolumn == "no", "create should disable the signcolumn")
assert_test(vim.wo[win].cursorline == true, "create should enable cursorline in the lesson window")
assert_test(vim.wo[win].wrap == false, "create should disable wrapping in the lesson window")

buffer.apply_playing_line_numbers(win, {
	number = true,
	relativenumber = false,
	statuscolumn = "",
})
assert_test(vim.wo[win].number == true, "apply_playing_line_numbers should restore absolute numbers when requested")
assert_test(
	vim.wo[win].statuscolumn:find("lesson_statuscolumn", 1, true) ~= nil,
	"apply_playing_line_numbers should install the lesson-owned statuscolumn formatter"
)

buffer.render(buf, {
	title = "Buffer Test",
	description = { "Describe the lesson" },
	progress = 2,
	max_progress = 5,
	snippet_lines = { "alpha", "beta" },
	hint_lines = { "Hint text" },
	goal_text = "Move to the target",
})

local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local snippet_offset, snippet_end = buffer.get_snippet_bounds()
assert_test(lines[1] == "  Buffer Test", "render should place the lesson title at the top of the buffer")
assert_test(lines[snippet_offset + 1] == "alpha", "render should record the first snippet row in layout metadata")
assert_test(lines[snippet_end + 1] == "beta", "render should record the final snippet row in layout metadata")

buffer.update_timer(buf, 65.2)
local timer_marks = vim.api.nvim_buf_get_extmarks(buf, highlight.ns_timer, 0, -1, { details = true })
assert_test(#timer_marks == 1, "update_timer should add a timer extmark to the progress line")
assert_test(
	timer_marks[1][4].virt_text[1][1] == "  01:05",
	"update_timer should render the elapsed timer in mm:ss format"
)

buffer.clear_timer(buf)
local cleared_marks = vim.api.nvim_buf_get_extmarks(buf, highlight.ns_timer, 0, -1, {})
assert_test(#cleared_marks == 0, "clear_timer should remove timer extmarks")

buffer.apply_nonplaying_line_numbers(win)
assert_test(
	vim.wo[win].number == false and vim.wo[win].relativenumber == false,
	"apply_nonplaying_line_numbers should hide lesson line numbers outside active challenges"
)

vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_buffer")
