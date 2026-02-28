-- vimteacher/lessons/intro_text_objects.lua
-- First lesson: Introduction to text objects

local M = {}

M.title = "Intro to Text Objects"
M.type = "info"
M.sandbox_modify_keys = { "d", "c", "y", "u", "<C-r>" }

M.description = {
	"Text objects let you act on structured chunks of text.",
	"Combine an operator (d, c, y) with a text object:",
	"",
	"  i = INSIDE (contents only, not the brackets/quotes)",
	"  a = AROUND (contents AND the brackets/quotes)",
	"",
	"  di( = delete inside parentheses: (hello) → ()",
	"  da( = delete around parens AND contents: x(hello)y → xy",
	'  ci" = change inside quotes: "old" → "" (type new text)',
	"",
	"Text objects work from ANYWHERE inside the pair —",
	"your cursor doesn't need to be on the opening bracket.",
	"",
	"Try some in the sandbox below!",
}

M.sandbox_snippet = {
	"-- Try di( to delete inside parens, da( to delete parens too",
	"",
	"function greet(name, age) {",
	'  const msg = "Hello, " + name;',
	"  const data = [1, 2, 3];",
	"  return { name: name, msg: msg };",
	"}",
}

M.hint_lines = {
	'[di(] Delete inside ()  [da(] Delete around ()  [ci"] Change inside ""',
	"[n] Next lesson      [q] Back to menu",
}

--- Generate a challenge (no-op for info lessons, satisfies registry validation).
--- @return table challenge
function M.generate_challenge()
	return {
		snippet_lines = vim.deepcopy(M.sandbox_snippet),
	}
end

return M
