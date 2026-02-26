-- tests/test_copy_paste_lines.lua
-- Tests for the copy_paste_lines lesson module (yy, p, P)

local copy_paste_lines = require("vimteacher.lessons.copy_paste_lines")

local pass_count = 0
local fail_count = 0

local function assert_test(condition, msg)
  if condition then
    pass_count = pass_count + 1
  else
    fail_count = fail_count + 1
    print("  FAIL: " .. msg)
  end
end

print("test_copy_paste_lines: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(copy_paste_lines.title ~= nil, "Missing title")
assert_test(type(copy_paste_lines.description) == "table", "description must be table")
assert_test(type(copy_paste_lines.hint_lines) == "table", "hint_lines must be table")
assert_test(type(copy_paste_lines.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(copy_paste_lines.type == "insert", "type must be 'insert', got " .. tostring(copy_paste_lines.type))
assert_test(type(copy_paste_lines.allowed_keys) == "table", "allowed_keys must be table")
assert_test(copy_paste_lines.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys is empty (no movement keys besides hjkl)
assert_test(#copy_paste_lines.allowed_keys == 0, "allowed_keys must be empty, got " .. #copy_paste_lines.allowed_keys)

-- Verify allowed_modify_keys contains p and P
assert_test(type(copy_paste_lines.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#copy_paste_lines.allowed_modify_keys == 2, "allowed_modify_keys must have 2 entries")
local modify_set = {}
for _, key in ipairs(copy_paste_lines.allowed_modify_keys) do
  modify_set[key] = true
end
assert_test(modify_set["p"] == true, "allowed_modify_keys must contain 'p'")
assert_test(modify_set["P"] == true, "allowed_modify_keys must contain 'P'")

-- Test 3: compute_optimal works (nav distance + yy + p/P = +2)
local opt1 = copy_paste_lines.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 0 })
assert_test(opt1 == 5, "Row 0 to Row 3 should be 3 + 2 = 5, got " .. opt1)

local opt2 = copy_paste_lines.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 0 })
assert_test(opt2 == 2, "Same row should be 0 + 2 = 2, got " .. opt2)

local opt3 = copy_paste_lines.compute_optimal({ row = 0, col = 5 }, { row = 4, col = 0 })
assert_test(opt3 == 6, "Row 0 to Row 4 should be 4 + 2 = 6, got " .. opt3)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_copy_paste_lines")
local challenge = copy_paste_lines.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key == nil, "key should not be exposed in generated challenge")
assert_test(challenge.goal_text ~= nil, "Missing goal_text")
assert_test(type(challenge.highlight_rows) == "table", "Missing highlight_rows")
assert_test(#challenge.highlight_rows == 1, "highlight_rows must have 1 row for yank target")
assert_test(challenge.yank_row ~= nil, "Missing yank_row")
assert_test(challenge.paste_after_row ~= nil, "Missing paste_after_row")

-- Test 5: expected_lines has exactly 1 more line than snippet_lines
assert_test(
  #challenge.expected_lines == #challenge.snippet_lines + 1,
  "expected_lines must have 1 more line than snippet_lines (paste adds a line), got "
    .. #challenge.expected_lines .. " expected " .. (#challenge.snippet_lines + 1)
)

-- Test 6: Target is the yank_row at column 0
assert_test(
  challenge.target.row == challenge.yank_row,
  "target.row must equal yank_row"
)
assert_test(
  challenge.target.col == 0,
  "target.col must be 0, got " .. challenge.target.col
)

-- Test 7: Yank_row is within snippet bounds
assert_test(challenge.yank_row >= 0, "yank_row must be >= 0")
assert_test(
  challenge.yank_row < #challenge.snippet_lines,
  "yank_row out of bounds: " .. challenge.yank_row .. " >= " .. #challenge.snippet_lines
)

-- Test 8: Paste_after_row is within snippet bounds
assert_test(challenge.paste_after_row >= 0, "paste_after_row must be >= 0")
assert_test(
  challenge.paste_after_row < #challenge.snippet_lines,
  "paste_after_row out of bounds: " .. challenge.paste_after_row .. " >= " .. #challenge.snippet_lines
)

-- Test 9: CRITICAL — Simulated edit correctness for ALL challenges
-- p: yank line at yank_row, insert copy BELOW paste_after_row
-- P: yank line at yank_row, insert copy ABOVE paste_after_row
local challenges = copy_paste_lines._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
  -- Validate required fields on each raw challenge
  assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
  assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
  assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
  assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
  assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
  assert_test(c.yank_row ~= nil, "Challenge " .. idx .. ": missing yank_row")
  assert_test(c.paste_after_row ~= nil, "Challenge " .. idx .. ": missing paste_after_row")
  assert_test(
    c.key == "p" or c.key == "P",
    "Challenge " .. idx .. ": key must be 'p' or 'P', got '" .. tostring(c.key) .. "'"
  )

  -- Verify expected_lines has 1 more line than snippet_lines
  assert_test(
    #c.expected_lines == #c.snippet_lines + 1,
    "Challenge " .. idx .. ": expected_lines count " .. #c.expected_lines
      .. " must equal snippet_lines count + 1 (" .. (#c.snippet_lines + 1) .. ")"
  )

  -- Verify yank_row is within snippet bounds
  assert_test(
    c.yank_row >= 0 and c.yank_row < #c.snippet_lines,
    "Challenge " .. idx .. ": yank_row " .. c.yank_row .. " out of bounds [0," .. (#c.snippet_lines - 1) .. "]"
  )

  -- Verify paste_after_row is within snippet bounds
  assert_test(
    c.paste_after_row >= 0 and c.paste_after_row < #c.snippet_lines,
    "Challenge " .. idx .. ": paste_after_row " .. c.paste_after_row .. " out of bounds [0," .. (#c.snippet_lines - 1) .. "]"
  )

  -- Verify target matches yank_row and col = 0
  assert_test(
    c.target.row == c.yank_row,
    "Challenge " .. idx .. ": target.row must equal yank_row"
  )
  assert_test(
    c.target.col == 0,
    "Challenge " .. idx .. ": target.col must be 0, got " .. c.target.col
  )

  -- Simulate the edit
  local edited = vim.deepcopy(c.snippet_lines)
  local yanked = edited[c.yank_row + 1]

  if c.key == "p" then
    -- p: insert yanked line BELOW paste_after_row (at index paste_after_row + 2)
    table.insert(edited, c.paste_after_row + 2, yanked)
  elseif c.key == "P" then
    -- P: insert yanked line ABOVE paste_after_row (at index paste_after_row + 1)
    table.insert(edited, c.paste_after_row + 1, yanked)
  end

  -- Compare edited snippet to expected_lines
  assert_test(
    #edited == #c.expected_lines,
    "Challenge " .. idx .. ": edited line count " .. #edited
      .. " != expected " .. #c.expected_lines
  )
  for i = 1, #c.expected_lines do
    assert_test(
      edited[i] == c.expected_lines[i],
      "Challenge " .. idx .. " line " .. i .. ": got '" .. edited[i]
        .. "' expected '" .. c.expected_lines[i] .. "'"
    )
  end
end

-- Test 10: Run 50 generations without crashes
for i = 1, 50 do
  local ch = copy_paste_lines.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
  assert_test(ch.yank_row ~= nil, "Generation " .. i .. " returned nil yank_row")
  assert_test(ch.paste_after_row ~= nil, "Generation " .. i .. " returned nil paste_after_row")
  assert_test(ch.goal_text ~= nil, "Generation " .. i .. " returned nil goal_text")
  assert_test(type(ch.highlight_rows) == "table", "Generation " .. i .. " missing highlight_rows")
  assert_test(
    #ch.expected_lines == #ch.snippet_lines + 1,
    "Generation " .. i .. ": expected must have 1 more line than snippet"
  )
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_copy_paste_lines: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
