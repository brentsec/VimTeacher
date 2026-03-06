-- vimteacher/ui/stats.lua
-- Challenge stats screen rendering.

local common = require("vimteacher.ui.common")
local highlight = require("vimteacher.highlight")

local M = {}

--- Render the stats overlay (replaces snippet zone content between challenges).
--- @param buf number Buffer handle
--- @param opts table Stats options
---   opts.title: string (lesson title)
---   opts.progress: number (current challenge just completed)
---   opts.max_progress: number
---   opts.time_secs: number
---   opts.best_time: number|nil
---   opts.speed_pct: number
---   opts.avg_time: number|nil
---   opts.accuracy_pct: number
---   opts.actual_moves: number
---   opts.optimal_moves: number
---   opts.description: string[] (lesson description for re-render)
---   opts.hint_lines: string[]
function M.render_challenge_stats(buf, opts)
	local lines = {}

	lines[#lines + 1] = "  " .. opts.title
	lines[#lines + 1] = ""

	for _, line in ipairs(opts.description) do
		lines[#lines + 1] = "  " .. line
	end
	lines[#lines + 1] = ""

	lines[#lines + 1] = "  " .. common.SEPARATOR
	local completed = opts.progress
	local remaining = opts.max_progress - completed
	local bar = string.rep("#", completed) .. string.rep(".", remaining)
	lines[#lines + 1] = string.format("  Challenge %d/%d   [%s]", opts.progress, opts.max_progress, bar)
	lines[#lines + 1] = "  " .. common.SEPARATOR
	lines[#lines + 1] = ""

	lines[#lines + 1] = "  CHALLENGE COMPLETE!"
	lines[#lines + 1] = ""

	local best_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
	lines[#lines + 1] = string.format("  Time:      %.1fs        Best: %s", opts.time_secs, best_str)
	lines[#lines + 1] = string.format("  Speed:     %d%%          (vs PB of %s)", opts.speed_pct, best_str)
	lines[#lines + 1] = string.format(
		"  Accuracy:  %d%%          (%d moves / %d optimal)",
		opts.accuracy_pct,
		opts.actual_moves,
		opts.optimal_moves
	)

	lines[#lines + 1] = ""
	lines[#lines + 1] = "  " .. common.SEPARATOR
	lines[#lines + 1] = ""

	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false

	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)
	vim.api.nvim_buf_clear_namespace(buf, highlight.ns_target, 0, -1)

	highlight.apply_line_highlight(buf, 0, 1, "VimTeacherTitle")

	for i, line in ipairs(lines) do
		if line:find("CHALLENGE COMPLETE!") then
			highlight.apply_line_highlight(buf, i - 1, i, "VimTeacherComplete")
		end
	end
end

return M
