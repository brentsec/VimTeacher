-- tests/test_delete_words.lua
-- Tests for the delete words lesson module (dw, dW)

local delete_words = require("vimteacher.lessons.delete_words")

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

print("test_delete_words: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(delete_words.title ~= nil, "Missing title")
assert_test(type(delete_words.description) == "table", "description must be table")
assert_test(type(delete_words.hint_lines) == "table", "hint_lines must be table")
assert_test(type(delete_words.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(delete_words.type == "insert", "type must be 'insert', got " .. tostring(delete_words.type))
assert_test(type(delete_words.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(delete_words.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_modify_keys contains exactly "d"
assert_test(#delete_words.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry, got " .. #delete_words.allowed_modify_keys)
assert_test(delete_words.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works (Manhattan distance)
local opt1 = delete_words.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = delete_words.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = delete_words.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_delete_words")
local challenge = delete_words.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(
  challenge.key == "dw" or challenge.key == "dW",
  "key must be 'dw' or 'dW', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: snippet_lines and expected_lines have same length (no line additions/removals)
assert_test(
  #challenge.snippet_lines == #challenge.expected_lines,
  "snippet_lines and expected_lines must have same length"
)

-- Test 6: snippet_lines and expected_lines differ (there's something to delete)
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

-- Test 9: CRITICAL — Simulated edit correctness for ALL challenges
-- dw: deletes from cursor to next word boundary (word chars + trailing space)
-- dW: deletes from cursor to next whitespace (WORD + trailing space)
local challenges = delete_words._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
  -- Validate required fields on each raw challenge
  assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
  assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
  assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
  assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
  assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
  assert_test(
    c.key == "dw" or c.key == "dW",
    "Challenge " .. idx .. ": key must be 'dw' or 'dW', got '" .. tostring(c.key) .. "'"
  )

  -- Verify same line count (dw/dW don't add/remove lines)
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

  -- Simulate the edit
  local edited = vim.deepcopy(c.snippet_lines)
  local line = edited[c.target.row + 1]
  local col = c.target.col

  if c.key == "dw" then
    -- dw: delete from cursor to next word boundary (word char + trailing space)
    local before = line:sub(1, col)
    local rest = line:sub(col + 1)
    -- Match word chars followed by optional whitespace
    local _, word_end = rest:find("^%S+%s*")
    if word_end then
      edited[c.target.row + 1] = before .. rest:sub(word_end + 1)
    else
      edited[c.target.row + 1] = before
    end
  elseif c.key == "dW" then
    -- dW: delete from cursor to next whitespace (WORD + trailing space)
    local before = line:sub(1, col)
    local rest = line:sub(col + 1)
    -- Match non-space chars followed by optional whitespace
    local _, word_end = rest:find("^%S+%s*")
    if word_end then
      edited[c.target.row + 1] = before .. rest:sub(word_end + 1)
    else
      edited[c.target.row + 1] = before
    end
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
  local ch = delete_words.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_delete_words: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
