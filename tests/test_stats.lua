-- tests/test_stats.lua
-- Tests for stats calculations

local stats = require("vimteacher.stats")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_stats: running...")

local function temp_stats_paths()
	local dir = vim.fn.tempname()
	local path = dir .. "/stats.json"
	vim.fn.mkdir(dir, "p")
	return dir, path
end

local function read_file(path)
	local f = io.open(path, "r")
	if not f then
		return nil
	end
	local content = f:read("*a")
	f:close()
	return content
end

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

-- Test 10: persistent stats path uses Neovim's data directory
local expected_path = vim.fn.stdpath("data") .. "/vimteacher/stats.json"
assert_test(
	stats._get_stats_path() == expected_path,
	"Stats path should use stdpath('data'), got " .. stats._get_stats_path()
)

-- Test 11: record_session — first session
local all = {}
local ls = stats.record_session(all, "test_lesson", 25.0, 80)
assert_test(ls.total_sessions == 1, "Expected 1 session, got " .. ls.total_sessions)
assert_test(ls.best_time == 25.0, "Expected best_time 25.0, got " .. tostring(ls.best_time))
assert_test(ls.avg_time == 25.0, "Expected avg_time 25.0, got " .. tostring(ls.avg_time))
assert_test(ls.best_accuracy == 80, "Expected best_accuracy 80, got " .. ls.best_accuracy)

-- Test 12: record_session — second session (faster)
local ls2 = stats.record_session(all, "test_lesson", 20.0, 90)
assert_test(ls2.total_sessions == 2, "Expected 2 sessions, got " .. ls2.total_sessions)
assert_test(ls2.best_time == 20.0, "Expected best_time 20.0, got " .. tostring(ls2.best_time))
assert_test(ls2.avg_time == 22.5, "Expected avg_time 22.5, got " .. tostring(ls2.avg_time))
assert_test(ls2.best_accuracy == 90, "Expected best_accuracy 90, got " .. ls2.best_accuracy)

-- Test 13: record_session — third session (slower, lower accuracy)
local ls3 = stats.record_session(all, "test_lesson", 30.0, 70)
assert_test(ls3.total_sessions == 3, "Expected 3 sessions, got " .. ls3.total_sessions)
assert_test(ls3.best_time == 20.0, "Best time should stay 20.0, got " .. tostring(ls3.best_time))
assert_test(ls3.best_accuracy == 90, "Best accuracy should stay 90, got " .. ls3.best_accuracy)

-- Test 14: record_session clamps out-of-range accuracy (>100)
local ls4 = stats.record_session(all, "test_lesson", 10.0, 110)
assert_test(ls4.best_accuracy == 100, "Best accuracy should clamp at 100, got " .. ls4.best_accuracy)

-- Test 15: clamp helper clamps negatives to 0
local clamped = stats.clamp_accuracy_pct(-15)
assert_test(clamped == 0, "Negative accuracy should clamp to 0, got " .. clamped)

-- Test 16: calc_overall_accuracy_pct caps at 100
local overall = stats.calc_overall_accuracy_pct(11, 10)
assert_test(overall == 100, "Overall accuracy should cap at 100, got " .. overall)

-- Test 17: normalize_optimal_moves clamps above actual
local norm1 = stats.normalize_optimal_moves(12, 9)
assert_test(norm1 == 9, "Optimal above actual should clamp to actual, got " .. norm1)

-- Test 18: normalize_optimal_moves keeps valid values
local norm2 = stats.normalize_optimal_moves(7, 9)
assert_test(norm2 == 7, "Optimal below actual should stay unchanged, got " .. norm2)

-- Test 19: normalize_optimal_moves clamps negatives/non-numbers
local norm3 = stats.normalize_optimal_moves(-5, -2)
assert_test(norm3 == 0, "Negative values should clamp to 0, got " .. norm3)
local norm4 = stats.normalize_optimal_moves("bad", 5)
assert_test(norm4 == 0, "Non-number optimal should clamp to 0, got " .. norm4)

-- Test 20: save/load round-trip uses atomic temp-file rename and normalized payloads
local temp_dir, temp_path = temp_stats_paths()
stats._set_test_paths({
	data_dir = temp_dir,
	stats_path = temp_path,
})

local persisted = {
	basic_movement = {
		best_time = 12.5,
		avg_time = 15.0,
		total_sessions = 2,
		total_time = 30.0,
		best_accuracy = 110,
		extra_field = "drop me",
	},
}

stats.save(persisted)
local raw_saved = read_file(temp_path)
assert_test(raw_saved ~= nil, "save should write the stats file at the overridden path")
local saved_names = vim.fn.readdir(temp_dir)
assert_test(#saved_names == 1 and saved_names[1] == "stats.json", "save should leave only the final stats file behind")

local reloaded = stats.load()
local saved_stats = reloaded.basic_movement
assert_test(saved_stats ~= nil, "load should round-trip saved lesson stats")
assert_test(saved_stats.best_time == 12.5, "round-trip should preserve best_time")
assert_test(saved_stats.total_sessions == 2, "round-trip should preserve total_sessions")
assert_test(saved_stats.total_time == 30.0, "round-trip should preserve total_time")
assert_test(saved_stats.avg_time == 15.0, "round-trip should preserve avg_time")
assert_test(saved_stats.best_accuracy == 100, "round-trip should clamp best_accuracy to 100")

-- Test 21: load drops malformed records and normalizes partial legacy data
local malformed = io.open(temp_path, "w")
if malformed then
	malformed:write(vim.fn.json_encode({
		valid = {
			best_time = 9.0,
			total_sessions = 3,
			total_time = 18.0,
			best_accuracy = -5,
		},
		legacy = {
			avg_time = 4.5,
			total_sessions = 2,
		},
		bad_shape = "ignore me",
		empty_name = {
			best_time = "bad",
		},
	}))
	malformed:close()
end

local normalized = stats.load()
assert_test(normalized.valid ~= nil, "load should keep valid lesson entries")
assert_test(normalized.valid.best_accuracy == 0, "load should clamp negative accuracy to 0")
assert_test(normalized.valid.avg_time == 6.0, "load should recompute avg_time from total_time/session count")
assert_test(normalized.legacy ~= nil, "load should keep partial legacy lesson entries")
assert_test(normalized.legacy.total_time == 9.0, "load should reconstruct total_time from avg_time when possible")
assert_test(normalized.legacy.avg_time == 4.5, "load should preserve reconstructed avg_time")
assert_test(normalized.bad_shape == nil, "load should discard non-table lesson entries")

stats._set_test_paths(nil)
vim.fn.delete(temp_dir, "rf")

counter.finish("test_stats")
