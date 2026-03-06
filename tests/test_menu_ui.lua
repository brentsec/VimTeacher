-- tests/test_menu_ui.lua
-- Tests for topic menu rendering metadata and copy.

local menu = require("vimteacher.ui.menu")
local highlight = require("vimteacher.highlight")
local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_menu_ui: running...")

local buf = vim.api.nvim_create_buf(false, true)
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)
highlight.setup()

menu.render_menu(buf, {
	{
		title = "Getting Started",
		lessons = {
			{ name = "intro_modes", title = "Intro to Modes" },
			{ name = "basic_movement", title = "Basic Movement: h, j, k, l" },
		},
	},
}, {}, win)

local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
local text = table.concat(lines, "\n")
assert_test(
	text:find("highlight a lesson and press Enter to start", 1, true) ~= nil,
	"menu hint should mention Enter on a highlighted lesson"
)

local row_map = vim.api.nvim_buf_get_var(buf, "vimteacher_menu_row_to_lesson")
local intro_row
local movement_row
for idx, line in ipairs(lines) do
	if line:find("1%.", 1) and line:find("Intro to Modes", 1, true) then
		intro_row = idx
	end
	if line:find("2%.", 1) and line:find("Basic Movement: h, j, k, l", 1, true) then
		movement_row = idx
	end
end

assert_test(intro_row ~= nil, "menu should render the first lesson row")
assert_test(movement_row ~= nil, "menu should render the second lesson row")
assert_test(row_map[intro_row] == 1, "menu row mapping should point first lesson row to lesson 1")
assert_test(row_map[movement_row] == 2, "menu row mapping should point second lesson row to lesson 2")

counter.finish("test_menu_ui")
