-- vimteacher/lessons/delete_lines.lua
-- Delete lines lesson: dd (delete whole line) and D (delete to end of line)

local M = {}

M.title = "Delete Lines: dd, D"
M.type = "insert"
M.allowed_keys = {}
M.allowed_modify_keys = { "d", "dd", "D" }
M.challenges_required = 10

M.description = {
  "Delete entire lines or parts of lines:",
  "",
  "  dd = delete the whole line (line disappears entirely)",
  "  D  = delete from cursor to end of line (line stays)",
  "",
  "  dd is actually d + d — the operator doubled acts on",
  "  the whole line. This pattern works for other operators too.",
  "",
  "Deleted text goes to your clipboard for pasting later.",
  "Navigate to the target and use the indicated key.",
}

M.hint_lines = {
  "[dd] Delete line  [D] Delete to end of line  [q] Menu",
}

-- Pre-defined challenge pool
-- dd challenges: delete whole line at target.row (expected_lines has 1 fewer line)
-- D challenges: delete from target.col to end of line (same line count, line truncated)
local CHALLENGES = {
  -- Challenge 1: dd — delete a comment line
  {
    snippet_lines = {
      "function add(a, b) {",
      "  // this is a temporary debug line",
      "  return a + b;",
      "}",
    },
    expected_lines = {
      "function add(a, b) {",
      "  return a + b;",
      "}",
    },
    target = { row = 1, col = 0 },
    start_pos = { row = 3, col = 0 },
    key = "dd",
  },

  -- Challenge 2: dd — delete a blank line
  {
    snippet_lines = {
      "function getData() {",
      "  const result = fetch(url);",
      "",
      "  return result;",
      "}",
    },
    expected_lines = {
      "function getData() {",
      "  const result = fetch(url);",
      "  return result;",
      "}",
    },
    target = { row = 2, col = 0 },
    start_pos = { row = 0, col = 0 },
    key = "dd",
  },

  -- Challenge 3: dd — delete a console.log line
  {
    snippet_lines = {
      "function process(data) {",
      "  console.log('Debug:', data);",
      "  const cleaned = data.trim();",
      "  return cleaned;",
      "}",
    },
    expected_lines = {
      "function process(data) {",
      "  const cleaned = data.trim();",
      "  return cleaned;",
      "}",
    },
    target = { row = 1, col = 0 },
    start_pos = { row = 4, col = 0 },
    key = "dd",
  },

  -- Challenge 4: dd — delete a duplicate line
  {
    snippet_lines = {
      "const port = 3000;",
      "const port = 3000;",
      "server.listen(port);",
    },
    expected_lines = {
      "const port = 3000;",
      "server.listen(port);",
    },
    target = { row = 1, col = 0 },
    start_pos = { row = 2, col = 0 },
    key = "dd",
  },

  -- Challenge 5: dd — delete an unused variable
  {
    snippet_lines = {
      "function calculate(x) {",
      "  const temp = x * 2;",
      "  const unused = 42;",
      "  return temp + 10;",
      "}",
    },
    expected_lines = {
      "function calculate(x) {",
      "  const temp = x * 2;",
      "  return temp + 10;",
      "}",
    },
    target = { row = 2, col = 0 },
    start_pos = { row = 0, col = 0 },
    key = "dd",
  },

  -- Challenge 6: D — delete trailing comment
  {
    snippet_lines = {
      "const port = 3000;",
      "const host = \"localhost\"; // TODO: use env var",
      "server.listen(port, host);",
    },
    expected_lines = {
      "const port = 3000;",
      "const host = \"localhost\";",
      "server.listen(port, host);",
    },
    target = { row = 1, col = 25 },
    start_pos = { row = 0, col = 0 },
    key = "D",
  },

  -- Challenge 7: D — delete function call arguments
  {
    snippet_lines = {
      "function init() {",
      "  connect();  // extra comment here",
      "  return true;",
      "}",
    },
    expected_lines = {
      "function init() {",
      "  connect();",
      "  return true;",
      "}",
    },
    target = { row = 1, col = 12 },
    start_pos = { row = 3, col = 0 },
    key = "D",
  },

  -- Challenge 8: D — delete trailing semicolons and extra content
  {
    snippet_lines = {
      "const name = \"Alice\";",
      "const age = 30;;; // extra semicolons",
      "console.log(name, age);",
    },
    expected_lines = {
      "const name = \"Alice\";",
      "const age = 30;",
      "console.log(name, age);",
    },
    target = { row = 1, col = 15 },
    start_pos = { row = 0, col = 0 },
    key = "D",
  },

  -- Challenge 9: D — delete inline comment
  {
    snippet_lines = {
      "function validate(input) {",
      "  return input.length > 0; // check not empty",
      "}",
    },
    expected_lines = {
      "function validate(input) {",
      "  return input.length > 0;",
      "}",
    },
    target = { row = 1, col = 26 },
    start_pos = { row = 2, col = 0 },
    key = "D",
  },

  -- Challenge 10: D — delete rest of line after certain point
  {
    snippet_lines = {
      "const config = {",
      "  debug: true, verbose: true, log: true",
      "};",
    },
    expected_lines = {
      "const config = {",
      "  debug: true",
      "};",
    },
    target = { row = 1, col = 13 },
    start_pos = { row = 0, col = 0 },
    key = "D",
  },
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- For dd: navigate to correct row (col doesn't matter), then 1 operation
--- For D: navigate to exact (row, col), then 1 operation
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  local moves = 0
  if start_pos.row ~= target.row then moves = moves + 1 end
  if start_pos.col ~= target.col then moves = moves + 1 end
  return moves + 1
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key}
function M.generate_challenge(buf, ns_id)
  -- Build list of eligible indices (not recently used)
  local eligible = {}
  for i = 1, #CHALLENGES do
    local dominated = false
    for _, r in ipairs(recent) do
      if r == i then dominated = true; break end
    end
    if not dominated then
      eligible[#eligible + 1] = i
    end
  end

  -- If all are recent, reset
  if #eligible == 0 then
    recent = {}
    for i = 1, #CHALLENGES do
      eligible[#eligible + 1] = i
    end
  end

  -- Pick random eligible challenge
  local idx = eligible[math.random(1, #eligible)]

  -- Update recency
  recent[#recent + 1] = idx
  if #recent > MAX_RECENT then
    table.remove(recent, 1)
  end

  local c = CHALLENGES[idx]
  return {
    snippet_lines = vim.deepcopy(c.snippet_lines),
    expected_lines = vim.deepcopy(c.expected_lines),
    target = { row = c.target.row, col = c.target.col },
    start_pos = { row = c.start_pos.row, col = c.start_pos.col },
    key = c.key,
  }
end

--- Expose challenge pool for testing.
function M._get_challenges()
  return CHALLENGES
end

return M
