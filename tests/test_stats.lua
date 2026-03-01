-- tests/test_stats.lua
-- Tests for stats calculations

local stats = require("vimteacher.stats")

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

print("test_stats: running...")

-- Test 1: calc_accuracy_pct — perfect path
local acc = stats.calc_accuracy_pct(5, 5)
assert_test(acc == 100, "Perfect path should be 100%, got " .. acc)

-- Test 2: calc_accuracy_pct — took double the moves
local acc2 = stats.calc_accuracy_pct(5, 10)
assert_test(acc2 == 50, "Double moves should be 50%, got " .. acc2)

-- Test 3: calc_accuracy_pct — zero actual moves
local acc3 = stats.calc_accuracy_pct(5, 0)
assert_test(acc3 == 100, "Zero moves should return 100%, got " .. acc3)

-- Test 4: calc_accuracy_pct — caps at 100%
local acc4 = stats.calc_accuracy_pct(10, 5)
assert_test(acc4 == 100, "Better than optimal should cap at 100%, got " .. acc4)

-- Test 5: calc_speed_pct — at personal best
local spd = stats.calc_speed_pct(2.0, 2.0)
assert_test(spd == 100, "At PB should be 100%, got " .. spd)

-- Test 6: calc_speed_pct — faster than PB clamps to 100
local spd2 = stats.calc_speed_pct(2.0, 1.0)
assert_test(spd2 == 100, "Faster than PB should cap at 100%, got " .. spd2)

-- Test 7: calc_speed_pct — slower than PB
local spd3 = stats.calc_speed_pct(2.0, 4.0)
assert_test(spd3 == 50, "Half as fast should be 50%, got " .. spd3)

-- Test 8: calc_speed_pct — no PB yet
local spd4 = stats.calc_speed_pct(nil, 2.0)
assert_test(spd4 == 100, "No PB should return 100%, got " .. spd4)

-- Test 9: calc_speed_pct — extreme fast case still caps at 100
local spd5 = stats.calc_speed_pct(10.0, 0.1)
assert_test(spd5 == 100, "Extreme fast case should cap at 100%, got " .. spd5)

-- Test 10: record_session — first session
local all = {}
local ls = stats.record_session(all, "test_lesson", 25.0, 80)
assert_test(ls.total_sessions == 1, "Expected 1 session, got " .. ls.total_sessions)
assert_test(ls.best_time == 25.0, "Expected best_time 25.0, got " .. tostring(ls.best_time))
assert_test(ls.avg_time == 25.0, "Expected avg_time 25.0, got " .. tostring(ls.avg_time))
assert_test(ls.best_accuracy == 80, "Expected best_accuracy 80, got " .. ls.best_accuracy)

-- Test 11: record_session — second session (faster)
local ls2 = stats.record_session(all, "test_lesson", 20.0, 90)
assert_test(ls2.total_sessions == 2, "Expected 2 sessions, got " .. ls2.total_sessions)
assert_test(ls2.best_time == 20.0, "Expected best_time 20.0, got " .. tostring(ls2.best_time))
assert_test(ls2.avg_time == 22.5, "Expected avg_time 22.5, got " .. tostring(ls2.avg_time))
assert_test(ls2.best_accuracy == 90, "Expected best_accuracy 90, got " .. ls2.best_accuracy)

-- Test 12: record_session — third session (slower, lower accuracy)
local ls3 = stats.record_session(all, "test_lesson", 30.0, 70)
assert_test(ls3.total_sessions == 3, "Expected 3 sessions, got " .. ls3.total_sessions)
assert_test(ls3.best_time == 20.0, "Best time should stay 20.0, got " .. tostring(ls3.best_time))
assert_test(ls3.best_accuracy == 90, "Best accuracy should stay 90, got " .. ls3.best_accuracy)

-- Test 13: record_session clamps out-of-range accuracy (>100)
local ls4 = stats.record_session(all, "test_lesson", 10.0, 110)
assert_test(ls4.best_accuracy == 100, "Best accuracy should clamp at 100, got " .. ls4.best_accuracy)

-- Test 14: clamp helper clamps negatives to 0
local clamped = stats.clamp_accuracy_pct(-15)
assert_test(clamped == 0, "Negative accuracy should clamp to 0, got " .. clamped)

-- Test 15: calc_overall_accuracy_pct caps at 100
local overall = stats.calc_overall_accuracy_pct(11, 10)
assert_test(overall == 100, "Overall accuracy should cap at 100, got " .. overall)

-- Test 16: normalize_optimal_moves clamps above actual
local norm1 = stats.normalize_optimal_moves(12, 9)
assert_test(norm1 == 9, "Optimal above actual should clamp to actual, got " .. norm1)

-- Test 17: normalize_optimal_moves keeps valid values
local norm2 = stats.normalize_optimal_moves(7, 9)
assert_test(norm2 == 7, "Optimal below actual should stay unchanged, got " .. norm2)

-- Test 18: normalize_optimal_moves clamps negatives/non-numbers
local norm3 = stats.normalize_optimal_moves(-5, -2)
assert_test(norm3 == 0, "Negative values should clamp to 0, got " .. norm3)
local norm4 = stats.normalize_optimal_moves("bad", 5)
assert_test(norm4 == 0, "Non-number optimal should clamp to 0, got " .. norm4)

print(string.format("test_stats: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
