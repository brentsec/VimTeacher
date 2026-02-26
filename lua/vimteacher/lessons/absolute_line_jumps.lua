-- vimteacher/lessons/absolute_line_jumps.lua
-- Lesson: Absolute line jumps with gg and G

local snippets = require("vimteacher.snippets")

local M = {}

M.title = "Jump to Top/Bottom: gg, G"

M.dwell_time = 50

M.description = {
  "Jump instantly to the top or bottom of the code:",
  "",
  "  gg = jump to the FIRST line",
  "  G  = jump to the LAST line",
  "",
  "In a real file, gg goes to line 1 and G goes to the end.",
  "These are essential for navigating large files quickly.",
  "",
  "Move your cursor to the green highlighted target.",
}

M.hint_lines = {
  "[gg] Jump to top  [G] Jump to bottom",
}

--- Compute the minimum (optimal) moves between two positions.
--- For absolute line jumps (gg/G), it's always 1 keypress.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  return 1
end

--- Generate a new challenge: random snippet with target on first or last line.
--- Start position is at the opposite end.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
  local snippet = snippets.get_random()

  -- Randomly choose first or last line for target
  local use_first = math.random() < 0.5
  local target_row = use_first and 0 or (#snippet - 1)

  -- Start position at opposite end
  local start_row = use_first and (#snippet - 1) or 0
  local start_line = snippet[start_row + 1]

  -- Pick non-whitespace column on start line
  local start_valid_cols = {}
  for col = 0, #start_line - 1 do
    local char = start_line:sub(col + 1, col + 1)
    if char ~= " " and char ~= "\t" then
      start_valid_cols[#start_valid_cols + 1] = col
    end
  end

  local start_col
  if #start_valid_cols == 0 then
    start_col = 0  -- Fallback
  else
    start_col = start_valid_cols[math.random(1, #start_valid_cols)]
  end

  local goal_text = use_first and "Move to the first line" or "Move to the last line"

  return {
    snippet_lines = snippet,
    target = { row = target_row, col = 0 },
    start_pos = { row = start_row, col = start_col },
    goal_text = goal_text,
    row_only_check = true,
    highlight_rows = { target_row },
  }
end

return M
