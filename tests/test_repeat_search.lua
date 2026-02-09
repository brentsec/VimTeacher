-- tests/test_repeat_search.lua
-- Tests for the repeat search lesson module

local repeat_search = require("vimteacher.lessons.repeat_search")

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

print("test_repeat_search: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(repeat_search.title ~= nil, "Missing title")
assert_test(type(repeat_search.description) == "table", "description must be table")
assert_test(type(repeat_search.hint_lines) == "table", "hint_lines must be table")
assert_test(type(repeat_search.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(repeat_search.compute_optimal) == "function", "compute_optimal must be function")

-- Test 2: compute_optimal works
-- Same position should return 0
local opt = repeat_search.compute_optimal({ row = 5, col = 10 }, { row = 5, col = 10 })
assert_test(opt == 0, "Same position should be 0, got " .. opt)

-- Different positions should return 2 (search + n)
local opt2 = repeat_search.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt2 == 2, "Different position should be 2, got " .. opt2)

local opt3 = repeat_search.compute_optimal({ row = 10, col = 20 }, { row = 1, col = 1 })
assert_test(opt3 == 2, "Different position should be 2, got " .. opt3)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_repeat_search")
local challenge = repeat_search.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(type(challenge.snippet_lines) == "table", "snippet_lines must be table")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.start_pos.row ~= nil, "Missing start_pos.row")
assert_test(challenge.start_pos.col ~= nil, "Missing start_pos.col")

-- Test 4: Custom snippets have repeated words
-- Check that at least one word appears 2+ times in the snippet
local function has_repeated_words(lines)
  local word_counts = {}
  for _, line in ipairs(lines) do
    -- Extract words (alphanumeric sequences)
    for word in line:gmatch("%w+") do
      local lower_word = word:lower()
      word_counts[lower_word] = (word_counts[lower_word] or 0) + 1
    end
  end

  for _, count in pairs(word_counts) do
    if count >= 2 then
      return true
    end
  end
  return false
end

assert_test(
  has_repeated_words(challenge.snippet_lines),
  "Custom snippets must have at least one repeated word"
)

-- Test 5: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
  challenge.target.row < #challenge.snippet_lines,
  "target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)
local target_line = challenge.snippet_lines[challenge.target.row + 1]
assert_test(target_line ~= nil, "target_line is nil")
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(
  challenge.target.col < #target_line,
  "target.col out of bounds: " .. challenge.target.col .. " >= " .. #target_line
)

-- Test 6: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(
  target_char ~= " " and target_char ~= "\t" and target_char ~= "",
  "Target must be on non-whitespace, got '" .. target_char .. "'"
)

-- Test 7: Start position is at least 3 rows away from target
local row_dist = math.abs(challenge.start_pos.row - challenge.target.row)
assert_test(
  row_dist >= 3,
  "Start must be >= 3 rows from target, got " .. row_dist
)

-- Test 8: Snippet has at least 8 lines (requirement for custom snippets)
assert_test(
  #challenge.snippet_lines >= 8,
  "Custom snippets must have 8+ lines, got " .. #challenge.snippet_lines
)

-- Test 9: Run 50 generations without crashes (stress test)
for i = 1, 50 do
  local ch = repeat_search.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")

  -- Verify snippet has repeated words
  assert_test(
    has_repeated_words(ch.snippet_lines),
    "Generation " .. i .. ": snippet missing repeated words"
  )

  -- Verify target is on non-whitespace
  local tl = ch.snippet_lines[ch.target.row + 1]
  if tl then
    local tc = tl:sub(ch.target.col + 1, ch.target.col + 1)
    assert_test(
      tc ~= " " and tc ~= "\t" and tc ~= "",
      "Generation " .. i .. ": target on whitespace/empty at ("
        .. ch.target.row .. "," .. ch.target.col .. ")"
    )
  else
    fail_count = fail_count + 1
    print("  FAIL: Generation " .. i .. ": target_line is nil at row " .. ch.target.row)
  end

  -- Verify start is 3+ rows away
  local rd = math.abs(ch.start_pos.row - ch.target.row)
  assert_test(
    rd >= 3,
    "Generation " .. i .. ": start must be >= 3 rows away, got " .. rd
  )
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_repeat_search: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
