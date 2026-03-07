-- vimteacher/init.lua
-- Main orchestrator: session lifecycle, state machine, and controller wiring.

local buffer = require("vimteacher.buffer")
local gameplay_mod = require("vimteacher.gameplay")
local highlight = require("vimteacher.highlight")
local input_mod = require("vimteacher.input")
local key_blocking = require("vimteacher.key_blocking")
local keymaps = require("vimteacher.keymaps")
local lessons = require("vimteacher.lessons")
local mode_keymaps_mod = require("vimteacher.mode_keymaps")
local session_mod = require("vimteacher.session")
local state_mod = require("vimteacher.state")
local stats_mod = require("vimteacher.stats")

local M = {}

local DEFAULT_CONFIG = {
	keymaps = {
		mode = "adaptive_display", -- strict | adaptive_display | adaptive_runtime
		distro = "auto",
		overrides = {},
	},
}

local GLOBAL_ADAPTIVE_KEYS = {
	"h",
	"j",
	"k",
	"l",
	"w",
	"e",
	"b",
	"W",
	"E",
	"B",
	"0",
	"$",
	"_",
	"f",
	"F",
	"t",
	"T",
	";",
	"i",
	"a",
	"I",
	"A",
	"o",
	"O",
	"x",
	"r",
	"cl",
	"cw",
	"cW",
	"dw",
	"dW",
	"dd",
	"dj",
	"dk",
	"d2j",
	"d2k",
	"D",
	"yy",
	"p",
	"P",
	"gg",
	"G",
	"{",
	"}",
	"/",
	"?",
	":",
	"n",
	"N",
	"*",
	"#",
	"d",
	"c",
	"di(",
	"di[",
	"di{",
	"da(",
	"da[",
	"da{",
	"ci(",
	"ci[",
	"ci{",
	"ca(",
	"ca[",
	"ca{",
	'di"',
	'da"',
	'ci"',
	'ca"',
	"di'",
	"da'",
	"ci'",
	"ca'",
	"diw",
	"daw",
	"ciw",
	"caw",
	"dip",
	"dap",
	"cip",
	"cap",
	"qa",
	"q",
	"@a",
	"@@",
	"<C-u>",
	"<C-d>",
	"v",
	"V",
	".",
}

local actions = {}
local input_controller, gameplay_controller, mode_keymap_controller, session_controller

local state = state_mod.session

local function current_win()
	local ok, win = pcall(vim.api.nvim_get_current_win)
	if ok and win and vim.api.nvim_win_is_valid(win) then
		return win
	end
	return nil
end

local function merged_config()
	local stored = vim.g.vimteacher_config
	if type(stored) ~= "table" then
		stored = {}
	end
	return vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_CONFIG), stored)
end

local function cleanup()
	if session_controller then
		session_controller.stop()
	end
end

local function block_insert_keys(exempt_keys)
	key_blocking.block_insert_keys(state.buf, exempt_keys)
end

input_controller = input_mod.new({
	state = state,
	lessons = lessons,
})

local function setup_menu_keymaps()
	input_controller.setup_menu_keymaps(actions.start_lesson, cleanup)
end

local function clear_menu_keymaps()
	input_controller.clear_menu_keymaps()
end

local function rerender_menu_layout()
	input_controller.rerender_menu_layout(buffer.render_menu)
end

gameplay_controller = gameplay_mod.new({
	state = state,
	advance_challenge = function()
		if actions.advance_challenge then
			actions.advance_challenge()
		end
	end,
	begin_challenge_timing = function()
		if actions.begin_challenge_timing then
			actions.begin_challenge_timing()
		end
	end,
	cleanup = cleanup,
	rerender_menu_layout = rerender_menu_layout,
})

mode_keymap_controller = mode_keymaps_mod.new({
	state = state,
})

session_controller = session_mod.new({
	state = state,
	gameplay = gameplay_controller,
	mode_keymaps = mode_keymap_controller,
	menu = {
		setup = setup_menu_keymaps,
		clear = clear_menu_keymaps,
	},
})

actions.advance_challenge = function()
	session_controller.advance_challenge()
end

actions.begin_challenge_timing = function()
	session_controller.begin_challenge_timing()
end

actions.show_menu = function()
	session_controller.show_menu()
end

actions.start_lesson = function(lesson_name)
	session_controller.start(lesson_name)
end

--- Configure VimTeacher behavior.
--- @param opts table|nil
function M.setup(opts)
	vim.g.vimteacher_config = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_CONFIG), opts or {})
end

--- Start VimTeacher. Shows the topic menu.
--- @param lesson_name string|nil Optional lesson name to jump directly into
function M.start(lesson_name)
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		cleanup()
	end

	highlight.setup()

	if state.saved_inccommand == nil then
		state.saved_inccommand = vim.o.inccommand
	end
	if vim.o.inccommand ~= "" then
		vim.o.inccommand = ""
	end

	state.config = merged_config()
	keymaps.configure(state.config.keymaps)
	state.key_display = nil
	if keymaps.is_adaptive_mode() then
		keymaps.capture()
		keymaps.capture_deferred()
		local diagnostics
		state.key_display, diagnostics = keymaps.resolve_many(GLOBAL_ADAPTIVE_KEYS)
		if diagnostics and #diagnostics.custom > 0 then
			local preview = {}
			for i = 1, math.min(8, #diagnostics.custom) do
				preview[#preview + 1] = diagnostics.custom[i]
			end
			local suffix = (#diagnostics.custom > 8) and ", ..." or ""
			vim.notify(
				"VimTeacher adaptive keymaps (" .. table.concat(preview, ", ") .. suffix .. ")",
				vim.log.levels.INFO
			)
		end
	end

	state.all_stats = stats_mod.load()
	state.source_window_line_numbers = buffer.capture_line_numbers(current_win())
	state.preferred_lesson_line_numbers = buffer.capture_preferred_line_numbers(current_win())

	state.buf, state.win = buffer.create()
	gameplay_controller.setup_autocmds()
	block_insert_keys()

	if lesson_name and lesson_name ~= "" then
		actions.start_lesson(lesson_name)
	else
		actions.show_menu()
	end
end

return M
