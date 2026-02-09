-- vimteacher/lessons/search.lua
-- Search lesson: / (forward) and ? (backward)

local snippets = require("vimteacher.snippets")

local M = {}

M.title = "Search: /, ?"

M.dwell_time = 50

M.description = {
  "Search for text anywhere in the file:",
  "",
  "  /text  = search FORWARD for 'text' (type /, then the word, then Enter)",
  "  ?text  = search BACKWARD for 'text' (type ?, then the word, then Enter)",
  "",
  "  After pressing /, a prompt appears at the bottom of the screen.",
  "  Type what you're looking for, then press Enter to jump to it.",
  "",
  "Use search to jump directly to the green highlighted target.",
}

M.hint_lines = {
  "[/text Enter] Search forward  [?text Enter] Search backward  [Esc] Cancel search",
}

--- Compute the minimum (optimal) moves between two positions.
--- For search, this is always 1 action (type / or ? + pattern + Enter).
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  if start_pos.row == target.row and start_pos.col == target.col then
    return 0
  end
  return 1 -- search always gets you there in 1 action
end

--- Generate a new challenge: random snippet + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
  local snippet = snippets.get_random()

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

  -- Pick a starting position at least 3 rows from target
  local candidates = {}
  for _, pos in ipairs(valid_positions) do
    local row_dist = math.abs(pos.row - target.row)
    if row_dist >= 3 then
      candidates[#candidates + 1] = pos
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
    -- Pick a random candidate
    start_pos = candidates[math.random(1, #candidates)]
  end

  return {
    snippet_lines = snippet,
    target = target,
    start_pos = start_pos,
  }
end

return M
