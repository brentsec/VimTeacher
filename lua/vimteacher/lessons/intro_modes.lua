-- vimteacher/lessons/intro_modes.lua
-- First lesson: Introduction to Vim modes (normal vs insert)

local M = {}

M.title = "Intro to Modes"
M.type = "info"

M.description = {
  "Vim has two main modes:",
  "",
  "  Normal mode — keys are COMMANDS (move cursor, not type text)",
  "  Insert mode — keys TYPE TEXT (like a regular editor)",
  "",
  "Right now you are in Normal mode. Try moving with h j k l.",
  "",
  "Press i to enter Insert mode — now you can type!",
  "Press Esc to return to Normal mode.",
  "",
  "Practice switching modes in the sandbox below.",
}

M.sandbox_snippet = {
  "-- Try it! Press i to type, Esc to go back",
  "",
  "function hello()",
  '  print("hello world")',
  "end",
}

M.hint_lines = {
  "[i] Enter insert mode    [Esc] Back to normal mode",
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
