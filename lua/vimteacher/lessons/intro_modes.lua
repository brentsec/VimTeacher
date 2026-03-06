-- vimteacher/lessons/intro_modes.lua
-- First lesson: Introduction to Vim modes (normal vs insert)

local base = require("vimteacher.lessons.base")

local M = base.define({
	title = "Intro to Modes",
	type = "info",
	adaptive_keys = { "h", "j", "k", "l", "i" },
	description_template = {
		"Vim has two main modes:",
		"",
		"  Normal mode — keys are COMMANDS (move cursor, not type text)",
		"  Insert mode — keys TYPE TEXT (like a regular editor)",
		"",
		"Right now you are in Normal mode. Try moving with {{left}} {{down}} {{up}} {{right}}.",
		"",
		"Press {{insert}} to enter Insert mode — now you can type!",
		"Press Esc to return to Normal mode.",
		"",
		"Practice switching modes in the sandbox below.",
	},
	sandbox_template = {
		"-- Try it! Press {{insert}} to type, Esc to go back",
		"",
		"function hello()",
		'  print("hello world")',
		"end",
	},
	hint_template = {
		"[{{insert}}] Enter insert mode    [Esc] Back to normal mode",
		"[n] Next lesson      [q] Back to menu",
	},
	template_tokens = {
		left = "h",
		down = "j",
		up = "k",
		right = "l",
		insert = "i",
	},
})
--- Generate a challenge (no-op for info lessons, satisfies registry validation).
--- @return table challenge
function M.generate_challenge()
	return {
		snippet_lines = vim.deepcopy(M.sandbox_snippet),
	}
end

return M
