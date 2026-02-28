-- vimteacher/lessons/switch_selection_ends.lua
-- Lesson: Switching selection ends in Visual mode using 'o'

local M = {}

M.title = "Switch Selection Ends: o"
M.type = "info"
M.sandbox_modify_keys = { "v", "V", "<C-v>" }

M.description = {
	"In Visual mode, you can jump between the two ends of your selection.",
	"",
	"  Press 'o' to jump to the OTHER end of the selection",
	"",
	"This is especially useful when you want to adjust the start of your",
	"selection instead of the end. For example:",
	"",
	"  1. Press v to enter Visual mode",
	"  2. Move to select some text (cursor is at end)",
	"  3. Press o to jump to the start",
	"  4. Now you can move to adjust the start of selection",
	"  5. Press o again to jump back to the end",
	"",
	"Try it in the sandbox below! Select some code and press o.",
}

M.sandbox_snippet = {
	"const greeting = 'hello';",
	"const message = 'world';",
	"const result = greeting + ' ' + message;",
	"",
	"function display() {",
	"  console.log(result);",
	"  return true;",
	"}",
}

M.hint_lines = {
	"[v] Start visual mode    [o] Switch to other end    [Esc] Cancel selection",
	"[Enter] Next lesson      [q] Back to menu",
}

--- Generate a challenge (no-op for info lessons, satisfies registry validation).
--- @return table challenge
function M.generate_challenge()
	return {
		snippet_lines = vim.deepcopy(M.sandbox_snippet),
	}
end

return M
