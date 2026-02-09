-- tests/test_absolute_line_jumps.lua
-- Tests for the absolute line jumps lesson module

local absolute = require("vimteacher.lessons.absolute_line_jumps")

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

print("test_absolute_line_jumps: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(absolute.title ~= nil, "Missing title")
assert_test(type(absolute.description) == "table", "description must be table")
assert_test(type(absolute.hint_lines) == "table", "hint_lines must be table")
assert_test(type(absolute.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(absolute.compute_optimal) == "function", "compute_optimal must be function")

-- Test 2: compute_optimal works - same position
local opt = absolute.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 0 })
assert_test(opt == 0, "Same position should be 0, got " .. opt)

-- Test 3: compute_optimal - same row, different col
local opt2 = absolute.compute_optimal({ row = 3, col = 2 }, { row = 3, col = 7 })
assert_test(opt2 == 1, "Same row, different col should be 1, got " .. opt2)

-- Test 4: compute_optimal - different row, same col
local opt3 = absolute.compute_optimal({ row = 0, col = 5 }, { row = 8, col = 5 })
assert_test(opt3 == 1, "Different row, same col should be 1 (gg/G), got " .. opt3)

-- Test 5: compute_optimal - different row and col
local opt4 = absolute.compute_optimal({ row = 1, col = 2 }, { row = 5, col = 7 })
assert_test(opt4 == 2, "Different row and col should be 2 (gg/G + col), got " .. opt4)

-- Test 6: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_absolute")
local challenge = absolute.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

-- Test 7: Target is ALWAYS on first line (row=0) or last line (row=#snippet-1)
local last_row = #challenge.snippet_lines - 1
assert_test(
  challenge.target.row == 0 or challenge.target.row == last_row,
  "Target must be on first (0) or last (" .. last_row .. ") line, got " .. challenge.target.row
)

-- Test 8: Target is within snippet bounds
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

-- Test 9: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(
  target_char ~= " " and target_char ~= "\t",
  "Target must be on non-whitespace, got '" .. target_char .. "'"
)

-- Test 10: Start position is at opposite end from target
if challenge.start_pos then
  if challenge.target.row == 0 then
    -- Target on first line, start should be on last line
    assert_test(
      challenge.start_pos.row == last_row,
      "Target on first line, start should be on last line (" .. last_row .. "), got " .. challenge.start_pos.row
    )
  else
    -- Target on last line, start should be on first line
    assert_test(
      challenge.start_pos.row == 0,
      "Target on last line, start should be on first line (0), got " .. challenge.start_pos.row
    )
  end
end

-- Test 11: Run 50 generations without crashes
for i = 1, 50 do
  local ch = absolute.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")

  -- Verify target is always on first or last line
  local last = #ch.snippet_lines - 1
  assert_test(
    ch.target.row == 0 or ch.target.row == last,
    "Generation " .. i .. ": target not on first/last line, got row " .. ch.target.row
  )

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

  -- Verify start is at opposite end
  if ch.start_pos then
    if ch.target.row == 0 then
      assert_test(
        ch.start_pos.row == last,
        "Generation " .. i .. ": target on first line, start not on last, got " .. ch.start_pos.row
      )
    else
      assert_test(
        ch.start_pos.row == 0,
        "Generation " .. i .. ": target on last line, start not on first, got " .. ch.start_pos.row
      )
    end
  end
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_absolute_line_jumps: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
