-- tests/test_validate.lua
-- Tests for position checking and cursor constraining

local validate = require("vimteacher.validate")

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

print("test_validate: running...")

-- Create a test buffer and window
local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "hello", "world", "test!" })
local win = vim.api.nvim_get_current_win()
vim.api.nvim_win_set_buf(win, buf)

-- Test 1: Exact match returns true
vim.api.nvim_win_set_cursor(win, { 1, 3 }) -- row 1 (1-indexed), col 3
local result = validate.check_position(win, 0, 3) -- row 0 (0-indexed), col 3
assert_test(result == true, "Expected match at (0, 3)")

-- Test 2: Wrong row returns false
local result2 = validate.check_position(win, 1, 3) -- row 1 but cursor is at row 0
assert_test(result2 == false, "Expected no match at (1, 3)")

-- Test 3: Wrong column returns false
local result3 = validate.check_position(win, 0, 4) -- right row, wrong col
assert_test(result3 == false, "Expected no match at (0, 4)")

-- Test 4: Constrain cursor upward
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
  "header line",
  "separator",
  "code line 1",
  "code line 2",
  "separator",
  "footer line",
})
vim.api.nvim_win_set_cursor(win, { 1, 0 }) -- line 1, in header zone
local constrained = validate.constrain_to_snippet(win, 2, 3) -- snippet lines 2-3 (0-indexed)
assert_test(constrained == true, "Cursor should have been constrained upward")
local new_pos = vim.api.nvim_win_get_cursor(win)
assert_test(new_pos[1] == 3, "Cursor should be on line 3 (1-indexed), got " .. new_pos[1])

-- Test 5: Constrain cursor downward
vim.api.nvim_win_set_cursor(win, { 6, 0 }) -- line 6, past snippet end
local constrained2 = validate.constrain_to_snippet(win, 2, 3)
assert_test(constrained2 == true, "Cursor should have been constrained downward")
local new_pos2 = vim.api.nvim_win_get_cursor(win)
assert_test(new_pos2[1] == 4, "Cursor should be on line 4 (1-indexed), got " .. new_pos2[1])

-- Test 6: Cursor within zone not constrained
vim.api.nvim_win_set_cursor(win, { 3, 2 }) -- line 3, within snippet zone
local constrained3 = validate.constrain_to_snippet(win, 2, 3)
assert_test(constrained3 == false, "Cursor within zone should not be constrained")

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_validate: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
