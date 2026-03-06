-- tests/test_recent.lua
-- Tests for shared recent-pick helpers.

local recent = require("vimteacher.recent")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_recent: running...")

-- Test 1: pick avoids entries already marked recent when alternatives exist.
local state1 = { 1, 2 }
local pick1 = recent.pick_avoiding_recent(3, state1, 2)
assert_test(pick1 == 3, "Expected only eligible pick 3, got " .. tostring(pick1))
assert_test(#state1 == 2, "Recent state should stay capped at 2, got " .. #state1)
assert_test(state1[1] == 2 and state1[2] == 3, "Recent state should roll forward to {2,3}")

-- Test 2: exhaustion clears the window and still returns an in-range pick.
local state2 = { 1, 2, 3 }
local pick2 = recent.pick_avoiding_recent(3, state2, 2)
assert_test(pick2 >= 1 and pick2 <= 3, "Exhausted pick should stay in range, got " .. tostring(pick2))
assert_test(#state2 == 1, "Exhausted state should reset before appending one pick, got " .. #state2)
assert_test(state2[1] == pick2, "Reset state should contain only the chosen pick")

-- Test 3: clear mutates the provided table in place.
local state3 = { 2, 4, 6 }
recent.clear(state3)
assert_test(#state3 == 0, "clear should empty the existing table, got size " .. #state3)

-- Test 4: invalid pool sizes are rejected.
local ok, err = pcall(function()
	recent.pick_avoiding_recent(0, {}, 2)
end)
assert_test(ok == false, "Expected invalid pool size to error")
assert_test(type(err) == "string" and err:find("positive pool size"), "Unexpected error: " .. tostring(err))

counter.finish("test_recent")
