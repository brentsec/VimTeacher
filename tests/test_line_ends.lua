-- tests/test_line_ends.lua
-- Tests for the line boundaries lesson module (0, $, _)

local line_ends = require("vimteacher.lessons.line_ends")

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

print("test_line_ends: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(line_ends.title ~= nil, "Missing title")
assert_test(type(line_ends.description) == "table", "description must be table")
assert_test(type(line_ends.hint_lines) == "table", "hint_lines must be table")
assert_test(type(line_ends.generate_challenge) == "function", "generate_challenge must be function")
assert_test(line_ends.dwell_time ~= nil, "Missing dwell_time")

-- Test 2: _find_line_boundaries on simple strings
local b1 = line_ends._find_line_boundaries({ "hello world" })
assert_test(#b1 == 1, "Expected 1 boundary entry, got " .. #b1)
assert_test(b1[1].row == 0, "Row should be 0")
assert_test(b1[1].col_0 == 0, "col_0 should be 0, got " .. b1[1].col_0)
assert_test(b1[1].col_end == 10, "col_end should be 10, got " .. b1[1].col_end)
assert_test(b1[1].col_first_nonblank == 0, "col_first_nonblank should be 0, got " .. b1[1].col_first_nonblank)

-- Test 3: _find_line_boundaries with indentation
local b2 = line_ends._find_line_boundaries({ "    indented text" })
assert_test(#b2 == 1, "Expected 1 boundary entry, got " .. #b2)
assert_test(b2[1].col_0 == 0, "col_0 should be 0")
assert_test(b2[1].col_end == 16, "col_end should be 16, got " .. b2[1].col_end)
assert_test(b2[1].col_first_nonblank == 4, "col_first_nonblank should be 4, got " .. b2[1].col_first_nonblank)

-- Test 4: _find_line_boundaries multiline with empty line
local b3 = line_ends._find_line_boundaries({ "abc", "", "  def" })
assert_test(#b3 == 2, "Expected 2 boundary entries (empty skipped), got " .. #b3)
assert_test(b3[1].row == 0, "First entry row should be 0")
assert_test(b3[2].row == 2, "Second entry row should be 2, got " .. b3[2].row)
assert_test(b3[2].col_first_nonblank == 2, "Second entry first_nonblank should be 2, got " .. b3[2].col_first_nonblank)

-- Test 5: _find_line_boundaries single character line
local b4 = line_ends._find_line_boundaries({ "x" })
assert_test(#b4 == 1, "Expected 1 boundary entry")
assert_test(b4[1].col_0 == 0, "col_0 should be 0")
assert_test(b4[1].col_end == 0, "col_end should be 0, got " .. b4[1].col_end)
assert_test(b4[1].col_first_nonblank == 0, "col_first_nonblank should be 0")

-- Test 6: compute_optimal
local opt1 = line_ends.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 0 })
assert_test(opt1 == 0, "Same position should be 0, got " .. opt1)

local opt2 = line_ends.compute_optimal({ row = 0, col = 5 }, { row = 0, col = 0 })
assert_test(opt2 == 1, "Same row different col should be 1, got " .. opt2)

local opt3 = line_ends.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 0 })
assert_test(opt3 == 2, "Different row should be 2, got " .. opt3)

local opt4 = line_ends.compute_optimal({ row = 2, col = 10 }, { row = 2, col = 0 })
assert_test(opt4 == 1, "Same row col 10 to col 0 should be 1, got " .. opt4)

-- Test 7: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_line_ends")
local challenge = line_ends.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

-- Test 8: Target is at a valid line boundary
local boundaries = line_ends._find_line_boundaries(challenge.snippet_lines)
local target_is_boundary = false
for _, b in ipairs(boundaries) do
  if b.row == challenge.target.row then
    if challenge.target.col == b.col_0
      or challenge.target.col == b.col_end
      or challenge.target.col == b.col_first_nonblank then
      target_is_boundary = true
    end
    break
  end
end
assert_test(target_is_boundary,
  "Target (" .. challenge.target.row .. "," .. challenge.target.col
    .. ") must be at a line boundary (0, $, or _)")

-- Test 9: Target row is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
  challenge.target.row < #challenge.snippet_lines,
  "target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)

-- Test 10: Target col is within line bounds
local tline = challenge.snippet_lines[challenge.target.row + 1]
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(
  challenge.target.col < #tline,
  "target.col out of bounds: " .. challenge.target.col .. " >= " .. #tline
)

-- Test 11: Run 50 generations without crashes + verify all targets are boundaries
for i = 1, 50 do
  local ch = line_ends.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")

  -- Verify target is at a valid boundary
  local gen_bounds = line_ends._find_line_boundaries(ch.snippet_lines)
  local is_boundary = false
  for _, b in ipairs(gen_bounds) do
    if b.row == ch.target.row then
      if ch.target.col == b.col_0
        or ch.target.col == b.col_end
        or ch.target.col == b.col_first_nonblank then
        is_boundary = true
      end
      break
    end
  end
  assert_test(is_boundary,
    "Generation " .. i .. ": target (" .. ch.target.row .. "," .. ch.target.col
      .. ") not at a line boundary")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_line_ends: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
