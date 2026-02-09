-- tests/test_delete_around_brackets.lua
-- Tests for the delete around brackets lesson module (da(, da[, da{)

local delete_around_brackets = require("vimteacher.lessons.delete_around_brackets")

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

print("test_delete_around_brackets: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(delete_around_brackets.title ~= nil, "Missing title")
assert_test(type(delete_around_brackets.description) == "table", "description must be table")
assert_test(type(delete_around_brackets.hint_lines) == "table", "hint_lines must be table")
assert_test(type(delete_around_brackets.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(delete_around_brackets.type == "insert", "type must be 'insert', got " .. tostring(delete_around_brackets.type))
assert_test(type(delete_around_brackets.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(delete_around_brackets.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_modify_keys contains exactly "d"
assert_test(#delete_around_brackets.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry, got " .. #delete_around_brackets.allowed_modify_keys)
assert_test(delete_around_brackets.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works (Manhattan distance)
local opt1 = delete_around_brackets.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = delete_around_brackets.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = delete_around_brackets.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = delete_around_brackets.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = delete_around_brackets.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_delete_around_brackets")
local challenge = delete_around_brackets.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(
  challenge.key == "da(" or challenge.key == "da[" or challenge.key == "da{",
  "key must be 'da(', 'da[', or 'da{', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: snippet_lines and expected_lines have same length (no line additions)
assert_test(
  #challenge.snippet_lines == #challenge.expected_lines,
  "snippet_lines and expected_lines must have same length"
)

-- Test 6: snippet_lines and expected_lines differ (there's something to fix)
local lines_differ = false
for i = 1, #challenge.snippet_lines do
  if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
    lines_differ = true
    break
  end
end
assert_test(lines_differ, "snippet_lines and expected_lines must differ")

-- Test 7: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
  challenge.target.row < #challenge.snippet_lines,
  "target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)
local target_line = challenge.snippet_lines[challenge.target.row + 1]
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(
  challenge.target.col < #target_line,
  "target.col out of bounds: " .. challenge.target.col .. " >= " .. #target_line
)

-- Test 8: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(
  target_char ~= " " and target_char ~= "\t",
  "Target must be on non-whitespace, got '" .. target_char .. "'"
)

-- Test 9: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
  local dist = math.abs(challenge.start_pos.row - challenge.target.row)
    + math.abs(challenge.start_pos.col - challenge.target.col)
  assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 10: CRITICAL — Simulated edit correctness for ALL challenges
-- da(, da[, da{ delete brackets AND contents
local challenges = delete_around_brackets._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
  -- Validate required fields on each raw challenge
  assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
  assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
  assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
  assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
  assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
  assert_test(
    c.key == "da(" or c.key == "da[" or c.key == "da{",
    "Challenge " .. idx .. ": key must be 'da(', 'da[', or 'da{', got '" .. tostring(c.key) .. "'"
  )

  -- Verify same line count (da( doesn't add/remove lines)
  assert_test(
    #c.expected_lines == #c.snippet_lines,
    "Challenge " .. idx .. ": expected_lines count " .. #c.expected_lines
      .. " must equal snippet_lines count " .. #c.snippet_lines
  )

  -- Verify target is within snippet bounds
  assert_test(
    c.target.row < #c.snippet_lines,
    "Challenge " .. idx .. ": target.row " .. c.target.row .. " >= " .. #c.snippet_lines
  )
  local sline = c.snippet_lines[c.target.row + 1]
  assert_test(
    c.target.col < #sline,
    "Challenge " .. idx .. ": target.col " .. c.target.col .. " >= " .. #sline
        .. " (line: '" .. sline .. "')"
  )

  -- Simulate the edit: find matching brackets, delete brackets + contents
  local edited = vim.deepcopy(c.snippet_lines)
  local line = edited[c.target.row + 1]
  local col = c.target.col

  -- Determine bracket pair from key
  local open_bracket, close_bracket
  if c.key == "da(" then
    open_bracket, close_bracket = "(", ")"
  elseif c.key == "da[" then
    open_bracket, close_bracket = "[", "]"
  elseif c.key == "da{" then
    open_bracket, close_bracket = "{", "}"
  end

  -- Find opening bracket (search backwards from target)
  local open_pos = nil
  for i = col, 0, -1 do
    local ch = line:sub(i + 1, i + 1)
    if ch == open_bracket then
      open_pos = i
      break
    end
  end

  -- Find closing bracket (search forwards from target)
  local close_pos = nil
  if open_pos then
    for i = open_pos + 1, #line - 1 do
      local ch = line:sub(i + 1, i + 1)
      if ch == close_bracket then
        close_pos = i
        break
      end
    end
  end

  -- Verify we found both brackets
  assert_test(
    open_pos ~= nil,
    "Challenge " .. idx .. ": Could not find opening bracket '" .. open_bracket .. "' before target"
  )
  assert_test(
    close_pos ~= nil,
    "Challenge " .. idx .. ": Could not find closing bracket '" .. close_bracket .. "' after opening"
  )

  -- Delete everything from open_pos to close_pos (inclusive)
  if open_pos and close_pos then
    edited[c.target.row + 1] = line:sub(1, open_pos) .. line:sub(close_pos + 2)
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

-- Test 11: Run 50 generations without crashes
for i = 1, 50 do
  local ch = delete_around_brackets.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_delete_around_brackets: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
