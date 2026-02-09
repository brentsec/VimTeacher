-- tests/test_open_lines.lua
-- Tests for the open lines lesson module (o and O)

local open_lines = require("vimteacher.lessons.open_lines")

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

print("test_open_lines: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(open_lines.title ~= nil, "Missing title")
assert_test(type(open_lines.description) == "table", "description must be table")
assert_test(type(open_lines.hint_lines) == "table", "hint_lines must be table")
assert_test(type(open_lines.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(open_lines.type == "insert", "type must be 'insert', got " .. tostring(open_lines.type))
assert_test(type(open_lines.allowed_keys) == "table", "allowed_keys must be table")
assert_test(#open_lines.allowed_keys == 2, "allowed_keys must have 2 entries")
assert_test(open_lines.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly o and O
local key_set = {}
for _, key in ipairs(open_lines.allowed_keys) do
  key_set[key] = true
end
assert_test(key_set["o"] == true, "allowed_keys must contain 'o'")
assert_test(key_set["O"] == true, "allowed_keys must contain 'O'")

-- Test 3: compute_optimal works
local opt1 = open_lines.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 2, "Different row should be 2, got " .. opt1)

local opt2 = open_lines.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = open_lines.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 1, "Same row different col should be 1, got " .. opt3)

local opt4 = open_lines.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 2, "Different row same col should be 2, got " .. opt4)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_open_lines")
local challenge = open_lines.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(
  challenge.key == "o" or challenge.key == "O",
  "key must be 'o' or 'O', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: expected_lines is longer than snippet_lines (a new line is added)
assert_test(
  #challenge.expected_lines == #challenge.snippet_lines + 1,
  "expected_lines must be exactly 1 longer than snippet_lines"
)

-- Test 6: snippet_lines and expected_lines differ
local lines_differ = false
-- They always differ since they have different lengths
if #challenge.snippet_lines ~= #challenge.expected_lines then
  lines_differ = true
else
  for i = 1, #challenge.snippet_lines do
    if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
      lines_differ = true
      break
    end
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
-- o inserts a new line AFTER target row; O inserts BEFORE target row.
-- Autoindent copies the indent from the target line; char has no indent.
local challenges = open_lines._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
  -- Validate required fields on each raw challenge
  assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
  assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
  assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
  assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
  assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
  assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")
  assert_test(
    c.key == "o" or c.key == "O",
    "Challenge " .. idx .. ": key must be 'o' or 'O', got '" .. tostring(c.key) .. "'"
  )

  -- Verify expected_lines is exactly 1 longer than snippet_lines
  assert_test(
    #c.expected_lines == #c.snippet_lines + 1,
    "Challenge " .. idx .. ": expected_lines must be snippet_lines + 1, got "
      .. #c.expected_lines .. " vs " .. #c.snippet_lines
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

  -- Simulate the edit: o/O inserts a new line with autoindent + char
  local edited = vim.deepcopy(c.snippet_lines)
  local indent = edited[c.target.row + 1]:match("^(%s*)")
  local new_line = indent .. c.char

  if c.key == "o" then
    -- o opens a new line AFTER target row
    table.insert(edited, c.target.row + 2, new_line)
  else
    -- O opens a new line BEFORE target row
    table.insert(edited, c.target.row + 1, new_line)
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
  local ch = open_lines.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_open_lines: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
