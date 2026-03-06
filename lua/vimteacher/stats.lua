-- vimteacher/stats.lua
-- Persistent stats: load/save JSON, speed%, accuracy%

local M = {}

--- Clamp a percentage to the user-facing 0-100 range.
--- @param pct number
--- @return number
function M.clamp_pct(pct)
	if type(pct) ~= "number" then
		return 0
	end
	return math.max(0, math.min(math.floor(pct), 100))
end

--- Clamp an accuracy percentage to the user-facing 0-100 range.
--- @param pct number
--- @return number
function M.clamp_accuracy_pct(pct)
	return M.clamp_pct(pct)
end

local function get_data_dir()
	return vim.fn.stdpath("data") .. "/vimteacher"
end

local function get_stats_path()
	return get_data_dir() .. "/stats.json"
end

M._get_stats_path = get_stats_path

--- Load stats from disk. Returns a table (empty if file doesn't exist).
--- @return table Stats table keyed by lesson name
function M.load()
	local path = get_stats_path()
	local f = io.open(path, "r")
	if not f then
		return {}
	end
	local content = f:read("*a")
	f:close()
	if not content or content == "" then
		return {}
	end
	local ok, data = pcall(vim.fn.json_decode, content)
	if ok and type(data) == "table" then
		-- Normalize historical stats in case older versions stored out-of-range values.
		for _, ls in pairs(data) do
			if type(ls) == "table" and ls.best_accuracy ~= nil then
				ls.best_accuracy = M.clamp_accuracy_pct(ls.best_accuracy)
			end
		end
		return data
	end
	return {}
end

--- Save stats to disk.
--- @param data table Stats table to save
function M.save(data)
	local dir = get_data_dir()
	vim.fn.mkdir(dir, "p")
	local path = get_stats_path()
	local json = vim.fn.json_encode(data)
	local f = io.open(path, "w")
	if f then
		f:write(json)
		f:close()
	end
end

--- Record a completed session and update running stats.
--- @param all_stats table Full stats table
--- @param lesson_name string Lesson identifier
--- @param total_time number Total time for the session (all challenges combined)
--- @param accuracy number Overall accuracy percentage (0-100)
--- @return table Updated lesson stats
function M.record_session(all_stats, lesson_name, total_time, accuracy)
	accuracy = M.clamp_accuracy_pct(accuracy)

	local ls = all_stats[lesson_name]
		or {
			best_time = nil,
			avg_time = nil,
			total_sessions = 0,
			total_time = 0,
			best_accuracy = 0,
		}

	ls.total_sessions = ls.total_sessions + 1
	ls.total_time = ls.total_time + total_time
	ls.avg_time = ls.total_time / ls.total_sessions

	if not ls.best_time or total_time < ls.best_time then
		ls.best_time = total_time
	end

	if accuracy > ls.best_accuracy then
		ls.best_accuracy = accuracy
	end

	all_stats[lesson_name] = ls
	return ls
end

--- Calculate speed percentage.
--- 100% means at or better than personal-best lesson time.
--- @param best_time number|nil Best recorded lesson time
--- @param current_time number Current lesson time
--- @return number Speed percentage (0-100, capped)
function M.clamp_speed_pct(pct)
	return M.clamp_pct(pct)
end

function M.calc_speed_pct(best_time, current_time)
	if not best_time or best_time <= 0 or current_time <= 0 then
		return 100
	end
	return M.clamp_speed_pct((best_time / current_time) * 100)
end

--- Clamp an estimated optimal move count so it never exceeds actual moves.
--- Keeps scoring/output internally consistent when heuristic optimal models are
--- beaten by advanced motion chains.
--- @param optimal_moves number
--- @param actual_moves number
--- @return number
function M.normalize_optimal_moves(optimal_moves, actual_moves)
	if type(optimal_moves) ~= "number" then
		optimal_moves = 0
	end
	if type(actual_moves) ~= "number" then
		actual_moves = 0
	end
	if actual_moves < 0 then
		actual_moves = 0
	end
	if optimal_moves < 0 then
		optimal_moves = 0
	end
	if optimal_moves > actual_moves then
		return actual_moves
	end
	return optimal_moves
end

--- Calculate accuracy percentage.
--- 100% means optimal path (minimum moves).
--- @param optimal_moves number Minimum moves required
--- @param actual_moves number Actual moves taken
--- @return number Accuracy percentage (0-100)
function M.calc_accuracy_pct(optimal_moves, actual_moves)
	if actual_moves <= 0 then
		return 100
	end
	if optimal_moves <= 0 then
		return 100
	end
	return M.clamp_accuracy_pct((optimal_moves / actual_moves) * 100)
end

--- Calculate overall/session accuracy percentage.
--- @param total_optimal number Sum of optimal moves across challenges
--- @param total_moves number Sum of actual moves across challenges
--- @return number Accuracy percentage (0-100)
function M.calc_overall_accuracy_pct(total_optimal, total_moves)
	return M.calc_accuracy_pct(total_optimal, total_moves)
end

return M
