-- vimteacher/lessons/line_inserts.lua
-- Fifth lesson: Inserting at line boundaries with I and A

local M = {}

M.title = "Line Inserts: I, A"
M.type = "insert"
M.allowed_keys = { "I", "A" }
M.challenges_required = 10

M.description = {
  "I and A are powerful shortcuts for inserting at line boundaries.",
  "",
  "  I = insert at the BEGINNING of the line (first non-blank)",
  "  A = append at the END of the line",
  "",
  "Navigate to the target line, then use I or A to fix the code.",
  "Press <Esc> when done.",
}

M.hint_lines = {
  "[I] Insert at line start  [A] Append at line end  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool. Each challenge has a "broken" snippet and the expected fix.
-- For `I` challenges: target is at first non-blank col (where I places cursor)
-- For `A` challenges: target is at last char col (A appends after it)
local CHALLENGES = {
  -- Challenge 1: I — insert 'f' before 'u' in 'unction'
  {
    snippet_lines = {
      "unction runTests() {",
      "  const result = test();",
      "  return result;",
      "}",
    },
    expected_lines = {
      "function runTests() {",
      "  const result = test();",
      "  return result;",
      "}",
    },
    target = { row = 0, col = 0 },
    start_pos = { row = 2, col = 0 },
    key = "I",
    char = "f",
  },

  -- Challenge 2: I — insert 'c' before 'o' in 'onst'
  {
    snippet_lines = {
      "function validate(input) {",
      "  onst name = input.trim();",
      "  return name.length > 0;",
      "}",
    },
    expected_lines = {
      "function validate(input) {",
      "  const name = input.trim();",
      "  return name.length > 0;",
      "}",
    },
    target = { row = 1, col = 2 },
    start_pos = { row = 3, col = 0 },
    key = "I",
    char = "c",
  },

  -- Challenge 3: I — insert 'r' before 'e' in 'eturn'
  {
    snippet_lines = {
      "function add(a, b) {",
      "  const sum = a + b;",
      "  eturn sum;",
      "}",
    },
    expected_lines = {
      "function add(a, b) {",
      "  const sum = a + b;",
      "  return sum;",
      "}",
    },
    target = { row = 2, col = 2 },
    start_pos = { row = 0, col = 0 },
    key = "I",
    char = "r",
  },

  -- Challenge 4: I — insert 'i' before 'f' in 'f (value > 0)'
  {
    snippet_lines = {
      "function check(value) {",
      "  f (value > 0) {",
      "    return true;",
      "  }",
      "}",
    },
    expected_lines = {
      "function check(value) {",
      "  if (value > 0) {",
      "    return true;",
      "  }",
      "}",
    },
    target = { row = 1, col = 2 },
    start_pos = { row = 3, col = 0 },
    key = "I",
    char = "i",
  },

  -- Challenge 5: I — insert 'l' before 'e' in 'et'
  {
    snippet_lines = {
      "function counter(items) {",
      "  et count = 0;",
      "  for (const item of items) {",
      "    count += 1;",
      "  }",
      "  return count;",
      "}",
    },
    expected_lines = {
      "function counter(items) {",
      "  let count = 0;",
      "  for (const item of items) {",
      "    count += 1;",
      "  }",
      "  return count;",
      "}",
    },
    target = { row = 1, col = 2 },
    start_pos = { row = 4, col = 0 },
    key = "I",
    char = "l",
  },

  -- Challenge 6: A — append ';' after '2' in 'const x = 42'
  {
    snippet_lines = {
      "function init() {",
      "  const x = 42",
      "  return x * 2;",
      "}",
    },
    expected_lines = {
      "function init() {",
      "  const x = 42;",
      "  return x * 2;",
      "}",
    },
    target = { row = 1, col = 13 },
    start_pos = { row = 3, col = 0 },
    key = "A",
    char = ";",
  },

  -- Challenge 7: A — append ')' after 'g' in 'console.log(msg'
  {
    snippet_lines = {
      "function log(msg) {",
      "  console.log(msg",
      "  return true;",
      "}",
    },
    expected_lines = {
      "function log(msg) {",
      "  console.log(msg)",
      "  return true;",
      "}",
    },
    target = { row = 1, col = 16 },
    start_pos = { row = 0, col = 0 },
    key = "A",
    char = ")",
  },

  -- Challenge 8: A — append ';' after ')' in 'data.parse()'
  {
    snippet_lines = {
      "function process(data) {",
      "  const result = data.parse()",
      "  return result;",
      "}",
    },
    expected_lines = {
      "function process(data) {",
      "  const result = data.parse();",
      "  return result;",
      "}",
    },
    target = { row = 1, col = 28 },
    start_pos = { row = 3, col = 0 },
    key = "A",
    char = ";",
  },

  -- Challenge 9: A — append ';' after 'l' in 'return val'
  {
    snippet_lines = {
      "function double(n) {",
      "  const val = n * 2;",
      "  return val",
      "}",
    },
    expected_lines = {
      "function double(n) {",
      "  const val = n * 2;",
      "  return val;",
      "}",
    },
    target = { row = 2, col = 11 },
    start_pos = { row = 0, col = 0 },
    key = "A",
    char = ";",
  },

  -- Challenge 10: A — append ';' after ')' in 'console.log(tag, msg)'
  {
    snippet_lines = {
      "function debug(msg) {",
      "  const tag = '[DEBUG]';",
      "  console.log(tag, msg)",
      "}",
    },
    expected_lines = {
      "function debug(msg) {",
      "  const tag = '[DEBUG]';",
      "  console.log(tag, msg);",
      "}",
    },
    target = { row = 2, col = 22 },
    start_pos = { row = 0, col = 0 },
    key = "A",
    char = ";",
  },
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- I/A jump to line start/end, so only row navigation matters.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  if start_pos.row == target.row and start_pos.col == target.col then return 0 end
  if start_pos.row == target.row then return 1 end
  return 2
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
