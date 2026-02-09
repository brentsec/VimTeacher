-- vimteacher/lessons/small_edits.lua
-- Seventh lesson: Character-level edits with cl, x, r

local M = {}

M.title = "Small Edits: cl, x, r"
M.type = "insert"
M.allowed_keys = { "c" }
M.allowed_modify_keys = { "x", "r" }
M.challenges_required = 10

M.description = {
  "Quick character-level edits without full insert mode:",
  "",
  "  x  = delete the character under the cursor",
  "  r  = replace character under cursor (type the replacement)",
  "  cl = change letter: delete char and enter insert mode",
  "",
  "Navigate to the green target and use the indicated key.",
}

M.hint_lines = {
  "[x] Delete char  [r] Replace char  [cl] Change letter  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool.
-- x: deletes the char at target — char field is the char being deleted (display only)
-- r: replaces the char at target with char field (single replacement char)
-- s: deletes the char at target, enters insert mode, user types char field (multi-char)
local CHALLENGES = {
  -- Challenge 1: x — delete extra 's' in 'conssole'
  {
    snippet_lines = {
      "function debug(msg) {",
      "  conssole.log(msg);",
      "  return true;",
      "}",
    },
    expected_lines = {
      "function debug(msg) {",
      "  console.log(msg);",
      "  return true;",
      "}",
    },
    target = { row = 1, col = 6 },
    start_pos = { row = 3, col = 0 },
    key = "x",
    char = "s",
  },

  -- Challenge 2: x — delete extra 't' in 'retturn'
  {
    snippet_lines = {
      "function getResult() {",
      "  const value = compute();",
      "  retturn value;",
      "}",
    },
    expected_lines = {
      "function getResult() {",
      "  const value = compute();",
      "  return value;",
      "}",
    },
    target = { row = 2, col = 5 },
    start_pos = { row = 0, col = 0 },
    key = "x",
    char = "t",
  },

  -- Challenge 3: x — delete extra 't' in 'ittem'
  {
    snippet_lines = {
      "function process(records) {",
      "  const ittem = records[0];",
      "  return item.name;",
      "}",
    },
    expected_lines = {
      "function process(records) {",
      "  const item = records[0];",
      "  return item.name;",
      "}",
    },
    target = { row = 1, col = 10 },
    start_pos = { row = 3, col = 0 },
    key = "x",
    char = "t",
  },

  -- Challenge 4: r — replace 'a' with 'o' in 'functian'
  {
    snippet_lines = {
      "functian add(a, b) {",
      "  return a + b;",
      "}",
    },
    expected_lines = {
      "function add(a, b) {",
      "  return a + b;",
      "}",
    },
    target = { row = 0, col = 6 },
    start_pos = { row = 2, col = 0 },
    key = "r",
    char = "o",
  },

  -- Challenge 5: r — replace 'f' with 'g' in 'console.lof'
  {
    snippet_lines = {
      "function warn(msg) {",
      "  console.lof(msg);",
      "  return false;",
      "}",
    },
    expected_lines = {
      "function warn(msg) {",
      "  console.log(msg);",
      "  return false;",
      "}",
    },
    target = { row = 1, col = 12 },
    start_pos = { row = 0, col = 0 },
    key = "r",
    char = "g",
  },

  -- Challenge 6: r — replace 'r' with 't' in 'resulr'
  {
    snippet_lines = {
      "function fetchData(url) {",
      "  const resulr = fetch(url);",
      "  return JSON.parse(data);",
      "}",
    },
    expected_lines = {
      "function fetchData(url) {",
      "  const result = fetch(url);",
      "  return JSON.parse(data);",
      "}",
    },
    target = { row = 1, col = 13 },
    start_pos = { row = 3, col = 0 },
    key = "r",
    char = "t",
  },

  -- Challenge 7: r — replace 'n' with 'r' in 'retunn'
  {
    snippet_lines = {
      "function isValid(input) {",
      "  const check = input.length > 0;",
      "  retunn check;",
      "}",
    },
    expected_lines = {
      "function isValid(input) {",
      "  const check = input.length > 0;",
      "  return check;",
      "}",
    },
    target = { row = 2, col = 6 },
    start_pos = { row = 0, col = 0 },
    key = "r",
    char = "r",
  },

  -- Challenge 8: cl — replace 'X' with 'let'
  {
    snippet_lines = {
      "function init(config) {",
      "  X items = config.list;",
      "  return items;",
      "}",
    },
    expected_lines = {
      "function init(config) {",
      "  let items = config.list;",
      "  return items;",
      "}",
    },
    target = { row = 1, col = 2 },
    start_pos = { row = 3, col = 0 },
    key = "cl",
    char = "let",
  },

  -- Challenge 9: cl — replace 'Z' with 'const'
  {
    snippet_lines = {
      "function setup() {",
      "  Z port = 3000;",
      "  return port;",
      "}",
    },
    expected_lines = {
      "function setup() {",
      "  const port = 3000;",
      "  return port;",
      "}",
    },
    target = { row = 1, col = 2 },
    start_pos = { row = 3, col = 0 },
    key = "cl",
    char = "const",
  },

  -- Challenge 10: cl — replace 'Y' with 'return'
  {
    snippet_lines = {
      "function sum(a, b) {",
      "  const total = a + b;",
      "  Y total;",
      "}",
    },
    expected_lines = {
      "function sum(a, b) {",
      "  const total = a + b;",
      "  return total;",
      "}",
    },
    target = { row = 2, col = 2 },
    start_pos = { row = 0, col = 0 },
    key = "cl",
    char = "return",
  },
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- For s/x/r, user must navigate to exact (row, col), so Manhattan distance applies.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  return math.abs(start_pos.row - target.row) + math.abs(start_pos.col - target.col)
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char}
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
    char = c.char,
  }
end

--- Expose challenge pool for testing.
function M._get_challenges()
  return CHALLENGES
end

return M
