-- tests/test_basic_movement.lua
-- Tests for the basic movement lesson module

local basic = require("vimteacher.lessons.basic_movement")

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

print("test_basic_movement: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(basic.title ~= nil, "Missing title")
assert_test(type(basic.description) == "table", "description must be table")
assert_test(type(basic.hint_lines) == "table", "hint_lines must be table")
assert_test(type(basic.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: compute_optimal works
local opt = basic.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt == 8, "Manhattan distance (0,0)->(3,5) should be 8, got " .. opt)

local opt2 = basic.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0 distance, got " .. opt2)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_basic")
local challenge = basic.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

-- Test 4: Target is within snippet bounds
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

-- Test 5: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(
  target_char ~= " " and target_char ~= "\t",
  "Target must be on non-whitespace, got '" .. target_char .. "'"
)

-- Test 6: Start position has Manhattan distance >= 3 from target
if challenge.start_pos then
  local dist = math.abs(challenge.start_pos.row - challenge.target.row)
    + math.abs(challenge.start_pos.col - challenge.target.col)
  assert_test(dist >= 3, "Start must be >= 3 Manhattan distance, got " .. dist)
end

-- Test 7: Run 50 generations without crashes
for i = 1, 50 do
  local ch = basic.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")

  -- Verify target is always on non-whitespace
  local tl = ch.snippet_lines[ch.target.row + 1]
  if tl then
    local tc = tl:sub(ch.target.col + 1, ch.target.col + 1)
    assert_test(
      tc ~= " " and tc ~= "\t" and tc ~= "",
      "Generation " .. i .. ": target on whitespace/empty at ("
        .. ch.target.row .. "," .. ch.target.col .. ")"
    )
  end
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_basic_movement: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
