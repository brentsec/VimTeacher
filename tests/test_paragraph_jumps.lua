-- tests/test_paragraph_jumps.lua
-- Tests for the paragraph jumps lesson module

local para = require("vimteacher.lessons.paragraph_jumps")

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

print("test_paragraph_jumps: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(para.title ~= nil, "Missing title")
assert_test(type(para.description) == "table", "description must be table")
assert_test(type(para.hint_lines) == "table", "hint_lines must be table")
assert_test(type(para.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(para.dwell_time) == "number", "dwell_time must be number")

-- Test 2: compute_optimal works (row difference only for paragraph jumps)
local opt = para.compute_optimal({ row = 0, col = 0 }, { row = 0, col = 0 })
assert_test(opt == 0, "Same position should be 0, got " .. opt)

local opt2 = para.compute_optimal({ row = 0, col = 5 }, { row = 0, col = 10 })
assert_test(opt2 == 1, "Same row, different col should be 1, got " .. opt2)

local opt3 = para.compute_optimal({ row = 5, col = 0 }, { row = 5, col = 0 })
assert_test(opt3 == 0, "Same position should be 0, got " .. opt3)

local opt4 = para.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 0 })
assert_test(opt4 == 1, "Different row, same col should be 1, got " .. opt4)

local opt5 = para.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 10 })
assert_test(opt5 == 2, "Different row and col should be 2, got " .. opt5)

-- Test 3: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_para")
local challenge = para.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")

-- Test 4: Snippet has at least one blank line (empty string "")
local has_blank = false
for _, line in ipairs(challenge.snippet_lines) do
  if line == "" then
    has_blank = true
    break
  end
end
assert_test(has_blank, "Snippet must have at least one blank line for paragraph boundaries")

-- Test 5: Target is within snippet bounds
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

-- Test 6: Target is on a non-whitespace character (not on blank line)
assert_test(
  target_line ~= "",
  "Target must not be on a blank line"
)
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(
  target_char ~= " " and target_char ~= "\t",
  "Target must be on non-whitespace, got '" .. target_char .. "'"
)

-- Test 7: Start position is at least 3 rows from target
if challenge.start_pos then
  local row_dist = math.abs(challenge.start_pos.row - challenge.target.row)
  assert_test(row_dist >= 3, "Start must be >= 3 rows from target, got " .. row_dist)
end

-- Test 8: Run 50 generations without crashes
for i = 1, 50 do
  local ch = para.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")

  -- Verify snippet has at least one blank line
  local has_blank_line = false
  for _, line in ipairs(ch.snippet_lines) do
    if line == "" then
      has_blank_line = true
      break
    end
  end
  assert_test(
    has_blank_line,
    "Generation " .. i .. ": snippet must have at least one blank line"
  )

  -- Verify target is always on non-whitespace and not on blank line
  local tl = ch.snippet_lines[ch.target.row + 1]
  if tl then
    assert_test(
      tl ~= "",
      "Generation " .. i .. ": target on blank line at row " .. ch.target.row
    )
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

print(string.format("test_paragraph_jumps: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
