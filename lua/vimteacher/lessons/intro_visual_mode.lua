-- vimteacher/lessons/intro_visual_mode.lua
-- First lesson: Introduction to Visual Mode (v, Esc)

local M = {}

M.title = "Intro to Visual Mode"
M.type = "info"
M.sandbox_modify_keys = { "v", "V", "<C-v>" }

M.description = {
  "Visual mode lets you SELECT text before acting on it:",
  "",
  "  v   = enter visual mode (start selecting)",
  "  Move your cursor — the selection grows as you move",
  "  Esc = cancel selection (exit visual mode)",
  "",
  "  It works like click-and-drag with a mouse, but faster!",
  "  Select text, then press an operator (d, c, y) to act on it.",
  "",
  "  Try pressing v, then move with h/j/k/l to see the selection.",
  "  Press Esc when done.",
}

M.sandbox_snippet = {
  "-- Try v to select, then move around, then Esc to deselect",
  "",
  "const items = [\"apple\", \"banana\", \"cherry\"];",
  "const total = items.length;",
  "console.log(total);",
}

M.hint_lines = {
  "[v] Start visual mode  [Esc] Cancel selection",
  "[Enter] Next lesson    [q] Back to menu",
}

--- Generate a challenge (no-op for info lessons, satisfies registry validation).
--- @return table challenge
function M.generate_challenge()
  return {
    snippet_lines = vim.deepcopy(M.sandbox_snippet),
  }
end

return M
