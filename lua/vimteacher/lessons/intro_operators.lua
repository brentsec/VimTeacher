-- vimteacher/lessons/intro_operators.lua
-- First lesson in Basic Operators section: Introduction to operators concept

local M = {}

M.title = "Intro to Operators"
M.type = "info"

M.description = {
  "Operators are action commands — think of them as VERBS.",
  "Motions (like w, $, j) are the OBJECTS they act on.",
  "",
  "  operator + motion = action",
  "",
  "  d + w = delete a word        (d is delete, w is word)",
  "  d + $ = delete to end of line ($ means end of line)",
  "  d + j = delete this line and the one below",
  "",
  "You already know motions (w, e, b, $, 0, f, t).",
  "Now you'll learn operators (d, c, y) to combine with them.",
  "",
  "Try pressing dw on a word in the sandbox below!",
}

M.sandbox_snippet = {
  "-- Try it! Press dw to delete a word, then u to undo",
  "",
  "const greeting = \"hello world\";",
  "const items = [\"apple\", \"banana\", \"cherry\"];",
  "console.log(greeting);",
}

M.hint_lines = {
  "[dw] Delete word  [d$] Delete to end  [u] Undo",
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
