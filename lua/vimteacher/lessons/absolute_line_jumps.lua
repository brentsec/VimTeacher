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
--- For absolute line jumps (gg/G), vertical move costs 1, column adjustment costs 1.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  if start_pos.row == target.row and start_pos.col == target.col then
    return 0
  end

  local moves = 0
  if start_pos.row ~= target.row then
    moves = moves + 1  -- gg or G
  end
  if start_pos.col ~= target.col then
    moves = moves + 1  -- column adjustment (h/l)
  end

  return moves
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
  local target_line = snippet[target_row + 1]

  -- Pick non-whitespace column on target line
  local valid_cols = {}
  for col = 0, #target_line - 1 do
    local char = target_line:sub(col + 1, col + 1)
    if char ~= " " and char ~= "\t" then
      valid_cols[#valid_cols + 1] = col
    end
  end

  -- Safety: if no valid columns (should never happen), retry
  if #valid_cols == 0 then
    return M.generate_challenge(buf, ns_id)
  end

  local target_col = valid_cols[math.random(1, #valid_cols)]

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

  return {
    snippet_lines = snippet,
    target = { row = target_row, col = target_col },
    start_pos = { row = start_row, col = start_col },
  }
end

return M
