-- vimteacher/lessons/relative_line_jumps.lua
-- Lesson: Relative line jumps with count + j/k (e.g., 5j, 3k)

local snippets = require("vimteacher.snippets")

local M = {}

M.title = "Line Jumps: 5j, 3k"

M.dwell_time = 50

M.description = {
  "Use count + j/k to jump multiple lines at once.",
  "",
  "  5j = jump 5 lines down",
  "  3k = jump 3 lines up",
  "",
  "Move your cursor to the green highlighted target below.",
}

M.hint_lines = {
  "[count+j] Jump down  [count+k] Jump up  [h/l] Adjust column — Move to the green target",
}

--- Compute the minimum (optimal) moves between two positions.
--- For relative line jumps: row difference = 1 move (counted jump), col difference = 1 move.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  if start_pos.row == target.row and start_pos.col == target.col then
    return 0
  end

  local moves = 0

  -- If different row, that's 1 move (counted jump: e.g., 5j)
  if start_pos.row ~= target.row then
    moves = moves + 1
  end

  -- If different column, that's 1 move (h/l)
  if start_pos.col ~= target.col then
    moves = moves + 1
  end

  return moves
end

--- Generate a new challenge: random snippet + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
  local snippet

  -- Ensure snippet has at least 8 lines (for meaningful line jumps)
  repeat
    snippet = snippets.get_random()
  until #snippet >= 8

  -- Build list of all valid target positions (non-whitespace characters)
  local valid_positions = {}
  for row_idx, line in ipairs(snippet) do
    for col_idx = 1, #line do
      local char = line:sub(col_idx, col_idx)
      if char ~= " " and char ~= "\t" then
        valid_positions[#valid_positions + 1] = {
          row = row_idx - 1, -- 0-indexed
          col = col_idx - 1, -- 0-indexed
        }
      end
    end
  end

  -- Safety: if no valid positions (should never happen with our pool), retry
  if #valid_positions == 0 then
    return M.generate_challenge(buf, ns_id)
  end

  -- Pick a random target
  local target = valid_positions[math.random(1, #valid_positions)]

  -- Pick a starting position at least 3 rows away vertically from target
  local candidates = {}
  for _, pos in ipairs(valid_positions) do
    local row_dist = math.abs(pos.row - target.row)
    if row_dist >= 3 then
      candidates[#candidates + 1] = {
        row = pos.row,
        col = pos.col,
        row_dist = row_dist
      }
    end
  end

  local start_pos
  if #candidates == 0 then
    -- Fallback: use first char of first non-empty line
    for i, line in ipairs(snippet) do
      if #line > 0 then
        start_pos = { row = i - 1, col = 0 }
        break
      end
    end
  else
    -- Prefer positions around 5-7 rows away (interesting but not tedious)
    table.sort(candidates, function(a, b)
      return math.abs(a.row_dist - 6) < math.abs(b.row_dist - 6)
    end)
    local top_n = math.min(5, #candidates)
    local chosen = candidates[math.random(1, top_n)]
    start_pos = { row = chosen.row, col = chosen.col }
  end

  return {
    snippet_lines = snippet,
    target = target,
    start_pos = start_pos,
  }
end

return M
