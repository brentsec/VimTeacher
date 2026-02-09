-- vimteacher/lessons/text_objects_mega_review.lua
-- Ninth lesson: Text Objects Mega Review - all types mixed

local M = {}

M.title = "Text Objects: Mega Review"
M.type = "insert"
M.allowed_keys = { "c" }
M.allowed_modify_keys = { "d" }
M.challenges_required = 10

M.description = {
  "Review all text object commands you have learned:",
  "",
  "  Brackets: di(  da(  ci(  ca(  (also [ and {)",
  "  Quotes:   di\"  da\"  ci\"  ca\"  (also ')",
  "  Words:    diw  daw  ciw  caw",
  "  Paragraphs: dip  dap  cip  cap",
  "",
  "  i = inside (keep delimiters)  a = around (remove delimiters)",
  "  d = delete  c = change (delete + type replacement)",
  "",
  "Navigate to the target and use the indicated command.",
}

M.hint_lines = {
  "[d/c + i/a + object] Use the command shown in the goal bar  [q] Menu",
}

-- Pre-defined challenge pool mixing all text object types
local CHALLENGES = {
  -- Bracket challenges (3-4 challenges)
  -- Challenge 1: di( — delete inside parens
  {
    snippet_lines = {
      "function format(data) {",
      "  console.log(data.name);",
      "  return data;",
      "}",
    },
    expected_lines = {
      "function format(data) {",
      "  console.log();",
      "  return data;",
      "}",
    },
    target = { row = 1, col = 15 },
    start_pos = { row = 3, col = 0 },
    key = "di(",
    char = "",
  },

  -- Challenge 2: ca{ — change around braces
  {
    snippet_lines = {
      "function init() {",
      "  const config = {debug: true};",
      "  return config;",
      "}",
    },
    expected_lines = {
      "function init() {",
      "  const config = production;",
      "  return config;",
      "}",
    },
    target = { row = 1, col = 20 },
    start_pos = { row = 0, col = 0 },
    key = "ca{",
    char = "production",
  },

  -- Challenge 3: da[ — delete around square brackets
  {
    snippet_lines = {
      "function process() {",
      "  const items = getList()[0];",
      "  return items;",
      "}",
    },
    expected_lines = {
      "function process() {",
      "  const items = getList();",
      "  return items;",
      "}",
    },
    target = { row = 1, col = 27 },
    start_pos = { row = 3, col = 0 },
    key = "da[",
    char = "",
  },

  -- Challenge 4: ci( — change inside parens
  {
    snippet_lines = {
      "function validate(input) {",
      "  if (input.length > 0) {",
      "    return true;",
      "  }",
      "}",
    },
    expected_lines = {
      "function validate(input) {",
      "  if (input !== null) {",
      "    return true;",
      "  }",
      "}",
    },
    target = { row = 1, col = 10 },
    start_pos = { row = 0, col = 0 },
    key = "ci(",
    char = "input !== null",
  },

  -- Quote challenges (3-4 challenges)
  -- Challenge 5: ci" — change inside double quotes
  {
    snippet_lines = {
      "function greet() {",
      "  const msg = \"hello world\";",
      "  return msg;",
      "}",
    },
    expected_lines = {
      "function greet() {",
      "  const msg = \"goodbye world\";",
      "  return msg;",
      "}",
    },
    target = { row = 1, col = 17 },
    start_pos = { row = 3, col = 0 },
    key = "ci\"",
    char = "goodbye world",
  },

  -- Challenge 6: da" — delete around double quotes
  {
    snippet_lines = {
      "function debug(level) {",
      "  console.log(\"debug\", level);",
      "  return level;",
      "}",
    },
    expected_lines = {
      "function debug(level) {",
      "  console.log(, level);",
      "  return level;",
      "}",
    },
    target = { row = 1, col = 17 },
    start_pos = { row = 0, col = 0 },
    key = "da\"",
    char = "",
  },

  -- Challenge 7: ca' — change around single quotes
  {
    snippet_lines = {
      "function setup() {",
      "  const mode = 'test';",
      "  return mode;",
      "}",
    },
    expected_lines = {
      "function setup() {",
      "  const mode = 'production';",
      "  return mode;",
      "}",
    },
    target = { row = 1, col = 18 },
    start_pos = { row = 3, col = 0 },
    key = "ca'",
    char = "'production'",
  },

  -- Challenge 8: di" — delete inside double quotes
  {
    snippet_lines = {
      "function fetchData(url) {",
      "  const endpoint = \"https://api.example.com\";",
      "  return fetch(endpoint);",
      "}",
    },
    expected_lines = {
      "function fetchData(url) {",
      "  const endpoint = \"\";",
      "  return fetch(endpoint);",
      "}",
    },
    target = { row = 1, col = 25 },
    start_pos = { row = 0, col = 0 },
    key = "di\"",
    char = "",
  },

  -- Word challenges (3-4 challenges)
  -- Challenge 9: diw — delete inner word
  {
    snippet_lines = {
      "function cleanup() {",
      "  const temp = getValue();",
      "  return result;",
      "}",
    },
    expected_lines = {
      "function cleanup() {",
      "  const  = getValue();",
      "  return result;",
      "}",
    },
    target = { row = 1, col = 9 },
    start_pos = { row = 3, col = 0 },
    key = "diw",
    char = "",
  },

  -- Challenge 10: daw — delete a word + space
  {
    snippet_lines = {
      "function process(data) {",
      "  remove extra word here;",
      "  return data;",
      "}",
    },
    expected_lines = {
      "function process(data) {",
      "  remove word here;",
      "  return data;",
      "}",
    },
    target = { row = 1, col = 10 },
    start_pos = { row = 0, col = 0 },
    key = "daw",
    char = "",
  },

  -- Challenge 11: ciw — change inner word
  {
    snippet_lines = {
      "function calculate() {",
      "  const oldValue = 100;",
      "  return oldValue;",
      "}",
    },
    expected_lines = {
      "function calculate() {",
      "  const newValue = 100;",
      "  return oldValue;",
      "}",
    },
    target = { row = 1, col = 10 },
    start_pos = { row = 3, col = 0 },
    key = "ciw",
    char = "newValue",
  },

  -- Challenge 12: caw — change a word + space
  {
    snippet_lines = {
      "function build() {",
      "  let old result = compute();",
      "  return result;",
      "}",
    },
    expected_lines = {
      "function build() {",
      "  let finalresult = compute();",
      "  return result;",
      "}",
    },
    target = { row = 1, col = 7 },
    start_pos = { row = 0, col = 0 },
    key = "caw",
    char = "final",
  },

  -- Paragraph challenges (3-4 challenges)
  -- Challenge 13: dip — delete inner paragraph
  {
    snippet_lines = {
      "const a = 1;",
      "const b = 2;",
      "",
      "console.log(a);",
      "console.log(b);",
      "",
      "return a + b;",
    },
    expected_lines = {
      "const a = 1;",
      "const b = 2;",
      "",
      "",
      "return a + b;",
    },
    target = { row = 3, col = 5 },
    start_pos = { row = 0, col = 0 },
    key = "dip",
    char = "",
  },

  -- Challenge 14: dap — delete a paragraph + blank line
  {
    snippet_lines = {
      "function main() {",
      "  const x = 1;",
      "",
      "  debug.log(x);",
      "  debug.info(x);",
      "",
      "  return x;",
      "}",
    },
    expected_lines = {
      "function main() {",
      "  const x = 1;",
      "",
      "  return x;",
      "}",
    },
    target = { row = 3, col = 2 },
    start_pos = { row = 7, col = 0 },
    key = "dap",
    char = "",
  },

  -- Challenge 15: cip — change inner paragraph
  {
    snippet_lines = {
      "const config = {",
      "  debug: true",
      "};",
      "",
      "const old = 1;",
      "const temp = 2;",
      "",
      "return config;",
    },
    expected_lines = {
      "const config = {",
      "  debug: true",
      "};",
      "",
      "const result = production();",
      "",
      "return config;",
    },
    target = { row = 4, col = 7 },
    start_pos = { row = 0, col = 0 },
    key = "cip",
    char = "const result = production();",
  },

  -- Challenge 16: cap — change a paragraph + blank line
  {
    snippet_lines = {
      "function init() {",
      "  const name = 'app';",
      "",
      "  temp = getValue();",
      "  debug = true;",
      "",
      "  return name;",
      "}",
    },
    expected_lines = {
      "function init() {",
      "  const name = 'app';",
      "",
      "  const config = setup();",
      "  return name;",
      "}",
    },
    target = { row = 3, col = 2 },
    start_pos = { row = 7, col = 0 },
    key = "cap",
    char = "  const config = setup();",
  },
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- Navigation (row + col movement) + 1 operation.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  local moves = 0
  if start_pos.row ~= target.row then moves = moves + 1 end
  if start_pos.col ~= target.col then moves = moves + 1 end
  return moves + 1  -- +1 for the text object operation
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
