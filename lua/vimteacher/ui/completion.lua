-- vimteacher/ui/completion.lua
-- Lesson completion screen rendering.

local common = require("vimteacher.ui.common")
local highlight = require("vimteacher.highlight")
local stats = require("vimteacher.stats")

local M = {}

--- Render the final completion screen for a lesson with session stats summary.
--- @param buf number Buffer handle
--- @param opts table Completion options
---   opts.title: string (lesson title)
---   opts.max_challenges: number (total challenges completed)
---   opts.session_challenges: table[] (list of {time, accuracy_pct, moves, optimal})
---   opts.best_time: number|nil (personal best from persistent stats)
---   opts.avg_time: number|nil (running average from persistent stats)
function M.render_completion(buf, opts)
	local total_time = 0
	local total_moves = 0
	local total_optimal = 0

	for _, c in ipairs(opts.session_challenges or {}) do
		total_time = total_time + c.time
		total_moves = total_moves + c.moves
		total_optimal = total_optimal + stats.normalize_optimal_moves(c.optimal, c.moves)
	end

	local num_challenges = #(opts.session_challenges or {})
	local avg_time = num_challenges > 0 and (total_time / num_challenges) or 0
	local overall_accuracy = stats.calc_overall_accuracy_pct(total_optimal, total_moves)

	local lines = {
		"",
		"  LESSON COMPLETE!",
		"",
		"  " .. opts.title,
		"  You completed all " .. opts.max_challenges .. " challenges.",
		"",
		"  " .. common.SEPARATOR,
		"  Session Summary",
		"  " .. common.SEPARATOR,
		"",
	}

	local pb_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
	lines[#lines + 1] =
		string.format("  Total time:     %-12sPersonal best:  %s", string.format("%.1fs", total_time), pb_str)

	local speed_pct = stats.calc_speed_pct(opts.best_time, total_time)
	local pb_hist_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
	lines[#lines + 1] = string.format(
		"  Avg/challenge:  %-12sSpeed: %d%% (vs PB of %s)",
		string.format("%.1fs", avg_time),
		speed_pct,
		pb_hist_str
	)

	lines[#lines + 1] = string.format(
		"  Accuracy:       %-12s(%d moves / %d optimal)",
		string.format("%d%%", overall_accuracy),
		total_moves,
		total_optimal
	)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. common.SEPARATOR
	lines[#lines + 1] = ""

	local nav_start = #lines
	lines[#lines + 1] = "  What's next:"
	lines[#lines + 1] = "    n   Move to the next topic"
	lines[#lines + 1] = "    p   Go back to the previous topic"
	lines[#lines + 1] = "    r   Restart this topic"
	lines[#lines + 1] = "    m   Return to topic menu"
	lines[#lines + 1] = "    q   Quit the tutorial"
	local nav_end = #lines

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. common.SEPARATOR
	lines[#lines + 1] = ""

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_target, 0, -1)

	highlight.apply_line_highlight(buf, 1, 2, "VimTeacherComplete")
	highlight.apply_line_highlight(buf, 3, 5, "VimTeacherTitle")
	highlight.apply_line_highlight(buf, 6, 7, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, 7, 8, "VimTeacherStatsHeader")
	highlight.apply_line_highlight(buf, 8, 9, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, nav_end, nav_end + 2, "VimTeacherSeparator")
	highlight.apply_line_highlight(buf, nav_start, nav_end, "VimTeacherHint")
end

return M
