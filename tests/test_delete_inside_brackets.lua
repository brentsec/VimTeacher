-- tests/test_delete_inside_brackets.lua
-- Tests for the delete inside brackets lesson module (di(, di[, di{)

local delete_inside_brackets = require("vimteacher.lessons.delete_inside_brackets")

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

print("test_delete_inside_brackets: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(delete_inside_brackets.title ~= nil, "Missing title")
assert_test(type(delete_inside_brackets.description) == "table", "description must be table")
assert_test(type(delete_inside_brackets.hint_lines) == "table", "hint_lines must be table")
assert_test(type(delete_inside_brackets.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(delete_inside_brackets.type == "insert", "type must be 'insert', got " .. tostring(delete_inside_brackets.type))
assert_test(type(delete_inside_brackets.allowed_keys) == "table", "allowed_keys must be table")
assert_test(delete_inside_brackets.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys is empty (text object operations don't use allowed_keys)
assert_test(#delete_inside_brackets.allowed_keys == 0, "allowed_keys must be empty, got " .. #delete_inside_brackets.allowed_keys)

-- Verify allowed_modify_keys contains only "d"
assert_test(type(delete_inside_brackets.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#delete_inside_brackets.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(delete_inside_brackets.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works (Manhattan distance + 1 for text object operation)
local opt1 = delete_inside_brackets.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 9, "Row 0,Col 0 to Row 3,Col 5 should be 8+1=9, got " .. opt1)

local opt2 = delete_inside_brackets.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 1, "Same position should be 0+1=1, got " .. opt2)

local opt3 = delete_inside_brackets.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 11, "Same row, col 0 to 10 should be 10+1=11, got " .. opt3)

local opt4 = delete_inside_brackets.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 4, "Row 0 to 3, same col should be 3+1=4, got " .. opt4)

local opt5 = delete_inside_brackets.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 9, "Row 1,Col 3 to Row 4,Col 8 should be 8+1=9, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_delete_inside_brackets")
local challenge = delete_inside_brackets.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(
  challenge.key == "di(" or challenge.key == "di[" or challenge.key == "di{",
  "key must be 'di(', 'di[', or 'di{', got '" .. tostring(challenge.key) .. "'"
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

-- Helper function to find matching brackets on a line
local function find_brackets(line, col, open_char, close_char)
  -- Find opening bracket before or at col
  local open_pos = nil
  for i = col + 1, 1, -1 do
    if line:sub(i, i) == open_char then
      open_pos = i - 1  -- Convert to 0-indexed
      break
    end
  end

  if not open_pos then
    return nil, nil
  end

  -- Find closing bracket after col
  local close_pos = nil
  for i = col + 1, #line do
    if line:sub(i, i) == close_char then
      close_pos = i - 1  -- Convert to 0-indexed
      break
    end
  end

  return open_pos, close_pos
end

-- Test 10: CRITICAL — Simulated edit correctness for ALL challenges
-- di(: deletes everything inside () on the same line
-- di[: deletes everything inside [] on the same line
-- di{: deletes everything inside {} on the same line
local challenges = delete_inside_brackets._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
  -- Validate required fields on each raw challenge
  assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
  assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
  assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
  assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
  assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
  assert_test(
    c.key == "di(" or c.key == "di[" or c.key == "di{",
    "Challenge " .. idx .. ": key must be 'di(', 'di[', or 'di{', got '" .. tostring(c.key) .. "'"
  )

  -- Verify same line count (text object operations don't add/remove lines)
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

  -- Simulate the text object edit
  local edited = vim.deepcopy(c.snippet_lines)
  local line = edited[c.target.row + 1]
  local col = c.target.col

  -- Determine bracket types
  local open_char, close_char
  if c.key == "di(" then
    open_char, close_char = "(", ")"
  elseif c.key == "di[" then
    open_char, close_char = "[", "]"
  elseif c.key == "di{" then
    open_char, close_char = "{", "}"
  end

  -- Find the opening and closing brackets
  local open_pos, close_pos = find_brackets(line, col, open_char, close_char)

  assert_test(
    open_pos ~= nil,
    "Challenge " .. idx .. ": could not find opening '" .. open_char .. "' before col " .. col .. " in line: '" .. line .. "'"
  )
  assert_test(
    close_pos ~= nil,
    "Challenge " .. idx .. ": could not find closing '" .. close_char .. "' after col " .. col .. " in line: '" .. line .. "'"
  )

  if open_pos and close_pos then
    -- Delete everything between the brackets (keep the brackets)
    local before_open = line:sub(1, open_pos)
    local after_close = line:sub(close_pos + 2)
    edited[c.target.row + 1] = before_open .. open_char .. close_char .. after_close

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
end

-- Test 11: Run 50 generations without crashes
for i = 1, 50 do
  local ch = delete_inside_brackets.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_delete_inside_brackets: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
