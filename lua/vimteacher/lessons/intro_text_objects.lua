-- vimteacher/lessons/intro_text_objects.lua
-- First lesson: Introduction to text objects

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Intro to Text Objects",
	type = "info",
	sandbox_modify_keys = { "d", "c", "y", "u", "<C-r>" },
	template_tokens = {
		d = "d",
		c = "c",
		y = "y",
		i = "i",
		a = "a",
		di_paren = "di(",
		da_paren = "da(",
		ci_quote = 'ci"',
	},
	description_template = {
		"Text objects let you act on structured chunks of text.",
		"Combine an operator ({{d}}, {{c}}, {{y}}) with a text object:",
		"",
		"  {{i}} = INSIDE (contents only, not the brackets/quotes)",
		"  {{a}} = AROUND (contents AND the brackets/quotes)",
		"",
		"  {{di_paren}} = delete inside parentheses: (hello) → ()",
		"  {{da_paren}} = delete around parens AND contents: x(hello)y → xy",
		'  {{ci_quote}} = change inside quotes: "old" → "" (type new text)',
		"",
		"Text objects work from ANYWHERE inside the pair —",
		"your cursor doesn't need to be on the opening bracket.",
		"",
		"Try some in the sandbox below!",
	},
	sandbox_template = {
		"-- Try {{di_paren}} to delete inside parens, {{da_paren}} to delete parens too",
		"",
		"function greet(name, age) {",
		'  const msg = "Hello, " + name;',
		"  const data = [1, 2, 3];",
		"  return { name: name, msg: msg };",
		"}",
	},
	hint_template = {
		'[{{di_paren}}] Delete inside ()  [{{da_paren}}] Delete around ()  [{{ci_quote}}] Change inside ""',
		"[n] Next lesson      [q] Back to menu",
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
