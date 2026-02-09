-- tests/test_visual_line_mode.lua
-- Tests for the visual line mode lesson module (V + d, V + c)

local visual_line_mode = require("vimteacher.lessons.visual_line_mode")

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

print("test_visual_line_mode: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(visual_line_mode.title ~= nil, "Missing title")
assert_test(type(visual_line_mode.description) == "table", "description must be table")
assert_test(type(visual_line_mode.hint_lines) == "table", "hint_lines must be table")
assert_test(type(visual_line_mode.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(visual_line_mode.type == "insert", "type must be 'insert', got " .. tostring(visual_line_mode.type))
assert_test(type(visual_line_mode.allowed_keys) == "table", "allowed_keys must be table")
assert_test(visual_line_mode.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(#visual_line_mode.allowed_keys == 1, "allowed_keys must have 1 entry, got " .. #visual_line_mode.allowed_keys)
assert_test(visual_line_mode.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains d
assert_test(type(visual_line_mode.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#visual_line_mode.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(visual_line_mode.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Verify allowed_visual_keys contains V
assert_test(type(visual_line_mode.allowed_visual_keys) == "table", "allowed_visual_keys must be table")
assert_test(#visual_line_mode.allowed_visual_keys == 1, "allowed_visual_keys must have 1 entry")
assert_test(visual_line_mode.allowed_visual_keys[1] == "V", "allowed_visual_keys[1] must be 'V'")

-- Test 3: compute_optimal works (Manhattan distance for visual line mode)
local opt1 = visual_line_mode.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = visual_line_mode.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = visual_line_mode.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = visual_line_mode.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = visual_line_mode.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_visual_line_mode")
local challenge = visual_line_mode.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(
  challenge.key == "Vd" or challenge.key == "Vjd" or challenge.key == "Vjjd" or challenge.key == "Vc",
  "key must be 'Vd', 'Vjd', 'Vjjd', or 'Vc', got '" .. tostring(challenge.key) .. "'"
)

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

-- Test 6: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
  local dist = math.abs(challenge.start_pos.row - challenge.target.row)
    + math.abs(challenge.start_pos.col - challenge.target.col)
  assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 7: CRITICAL — Simulated edit correctness for ALL challenges
-- Vd: select current line, delete (removes 1 line)
-- Vjd: select current + next line, delete (removes 2 lines)
-- Vjjd: select current + 2 below, delete (removes 3 lines)
-- Vc: select line, delete and insert replacement (char field)
local challenges = visual_line_mode._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
  -- Validate required fields on each raw challenge
  assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
  assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
  assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
  assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
  assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
  assert_test(
    c.key == "Vd" or c.key == "Vjd" or c.key == "Vjjd" or c.key == "Vc",
    "Challenge " .. idx .. ": key must be 'Vd', 'Vjd', 'Vjjd', or 'Vc', got '" .. tostring(c.key) .. "'"
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
  local edited = {}

  if c.key == "Vd" then
    -- Delete 1 line at target.row
    for i = 1, #c.snippet_lines do
      if i - 1 ~= c.target.row then
        edited[#edited + 1] = c.snippet_lines[i]
      end
    end
    -- Verify expected has 1 fewer line
    assert_test(
      #c.expected_lines == #c.snippet_lines - 1,
      "Challenge " .. idx .. " (Vd): expected should have 1 fewer line"
    )
  elseif c.key == "Vjd" then
    -- Delete 2 lines starting at target.row
    for i = 1, #c.snippet_lines do
      if not (i - 1 == c.target.row or i - 1 == c.target.row + 1) then
        edited[#edited + 1] = c.snippet_lines[i]
      end
    end
    -- Verify expected has 2 fewer lines
    assert_test(
      #c.expected_lines == #c.snippet_lines - 2,
      "Challenge " .. idx .. " (Vjd): expected should have 2 fewer lines"
    )
  elseif c.key == "Vjjd" then
    -- Delete 3 lines starting at target.row
    for i = 1, #c.snippet_lines do
      if not (i - 1 == c.target.row or i - 1 == c.target.row + 1 or i - 1 == c.target.row + 2) then
        edited[#edited + 1] = c.snippet_lines[i]
      end
    end
    -- Verify expected has 3 fewer lines
    assert_test(
      #c.expected_lines == #c.snippet_lines - 3,
      "Challenge " .. idx .. " (Vjjd): expected should have 3 fewer lines"
    )
  elseif c.key == "Vc" then
    -- Delete line at target.row and insert replacement (c.char)
    assert_test(c.char ~= nil, "Challenge " .. idx .. " (Vc): missing char field")
    for i = 1, #c.snippet_lines do
      if i - 1 == c.target.row then
        edited[#edited + 1] = c.char
      else
        edited[#edited + 1] = c.snippet_lines[i]
      end
    end
    -- Verify expected has same line count
    assert_test(
      #c.expected_lines == #c.snippet_lines,
      "Challenge " .. idx .. " (Vc): expected should have same line count"
    )
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
      "Challenge " .. idx .. " line " .. i .. ": got '" .. tostring(edited[i])
        .. "' expected '" .. c.expected_lines[i] .. "'"
    )
  end
end

-- Test 8: Run 50 generations without crashes
for i = 1, 50 do
  local ch = visual_line_mode.generate_challenge(buf, ns)
  assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
  assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
  assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
  assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_visual_line_mode: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
  vim.cmd("cquit! 1")
end
