-- vimteacher/lessons/intro_visual_mode.lua
-- First lesson: Introduction to Visual Mode (v, Esc)

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Intro to Visual Mode",
	type = "info",
	sandbox_modify_keys = { "v", "V", "<C-v>" },
	template_tokens = {
		v = "v",
		Esc = "Esc",
		d = "d",
		c = "c",
		y = "y",
		h = "h",
		j = "j",
		k = "k",
		l = "l",
	},
	description_template = {
		"Visual mode lets you SELECT text before acting on it:",
		"",
		"  {{v}}   = enter visual mode (start selecting)",
		"  Move your cursor — the selection grows as you move",
		"  {{Esc}} = cancel selection (exit visual mode)",
		"",
		"  It works like click-and-drag with a mouse, but faster!",
		"  Select text, then press an operator ({{d}}, {{c}}, {{y}}) to act on it.",
		"",
		"  Try pressing {{v}}, then move with {{h}}/{{j}}/{{k}}/{{l}} to see the selection.",
		"  Press {{Esc}} when done.",
	},
	sandbox_template = {
		"-- Try {{v}} to select, then move around, then {{Esc}} to deselect",
		"",
		'const items = ["apple", "banana", "cherry"];',
		"const total = items.length;",
		"console.log(total);",
	},
	hint_template = {
		"[{{v}}] Start visual mode  [{{Esc}}] Cancel selection",
		"[n] Next lesson    [q] Back to menu",
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
