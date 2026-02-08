-- vimteacher/buffer.lua
-- Buffer creation, layout rendering, and screen management

local highlight = require("vimteacher.highlight")

local M = {}

-- Stored layout metadata for the current render
local layout_meta = {
  snippet_offset = 0,
  snippet_end = 0,
}

local SEPARATOR = string.rep("─", 68)

--- Create a scratch buffer and configure the window.
--- @return number buf Buffer handle
--- @return number win Window handle
function M.create()
  local buf = vim.api.nvim_create_buf(false, true)

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "vimteacher"
  vim.bo[buf].undolevels = -1

  local win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)

  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = "no"
  vim.wo[win].cursorline = true
  vim.wo[win].wrap = false
  vim.wo[win].colorcolumn = ""
  vim.wo[win].foldmethod = "manual"
  vim.wo[win].foldenable = false

  return buf, win
end

--- Render the topic selection menu.
--- @param buf number Buffer handle
--- @param lessons table Ordered list of {name, title} tables
--- @param all_stats table Stats data keyed by lesson name
function M.render_menu(buf, lessons, all_stats)
  local lines = {
    "",
    "  VimTeacher",
    "",
    "  Select a Topic",
    "",
    "  #   Topic                          Best Time   Best Accuracy",
    "  " .. SEPARATOR,
  }

  for i, lesson in ipairs(lessons) do
    local ls = all_stats[lesson.name]
    local best_time = "  --"
    local best_acc = "  --"
    if ls then
      if ls.best_time then
        best_time = string.format("%.1fs", ls.best_time)
      end
      if ls.best_accuracy and ls.best_accuracy > 0 then
        best_acc = string.format("%d%%", ls.best_accuracy)
      end
    end

    local line = string.format("  %-4s%-35s%-12s%s", i .. ".", lesson.title, best_time, best_acc)
    lines[#lines + 1] = line
  end

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. SEPARATOR
  lines[#lines + 1] = ""
  lines[#lines + 1] = "  Type a number to start, or q to quit"
  lines[#lines + 1] = ""

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Apply highlights
  highlight.apply_line_highlight(buf, 1, 2, "VimTeacherTitle")
  highlight.apply_line_highlight(buf, 3, 4, "VimTeacherStatsHeader")
  highlight.apply_line_highlight(buf, 5, 6, "VimTeacherHint")
  highlight.apply_line_highlight(buf, 6, 7, "VimTeacherSeparator")

  -- Highlight menu item numbers
  local menu_start = 7
  for i = 1, #lessons do
    highlight.apply_line_highlight(buf, menu_start + i - 1, menu_start + i, "VimTeacherMenuItem")
  end

  -- Bottom hint
  local hint_line = #lines - 2
  highlight.apply_line_highlight(buf, hint_line, hint_line + 1, "VimTeacherHint")
end

--- Render the lesson layout with description, progress bar, and code snippet.
--- @param buf number Buffer handle
--- @param opts table Render options
---   opts.title: string
---   opts.description: string[]
---   opts.progress: number (current challenge, 1-based)
---   opts.max_progress: number (total challenges)
---   opts.snippet_lines: string[]
---   opts.hint_lines: string[]
function M.render(buf, opts)
  local lines = {}

  -- Title
  lines[#lines + 1] = "  " .. opts.title
  lines[#lines + 1] = ""

  -- Description
  local desc_start = #lines
  for _, line in ipairs(opts.description) do
    lines[#lines + 1] = "  " .. line
  end
  local desc_end = #lines
  lines[#lines + 1] = ""

  -- Separator + Progress + Separator
  lines[#lines + 1] = "  " .. SEPARATOR
  local progress_line = #lines
  local completed = opts.progress - 1
  local remaining = opts.max_progress - completed
  local bar = string.rep("#", completed) .. string.rep(".", remaining)
  lines[#lines + 1] = string.format("  Challenge %d/%d   [%s]", opts.progress, opts.max_progress, bar)
  lines[#lines + 1] = "  " .. SEPARATOR
  lines[#lines + 1] = ""

  -- Code snippet zone
  local snippet_offset = #lines -- 0-indexed line where snippet starts
  for _, line in ipairs(opts.snippet_lines) do
    lines[#lines + 1] = line
  end
  local snippet_end = #lines - 1 -- 0-indexed last line of snippet

  lines[#lines + 1] = ""

  -- Bottom separator + hints
  lines[#lines + 1] = "  " .. SEPARATOR
  local hint_start = #lines
  for _, line in ipairs(opts.hint_lines) do
    lines[#lines + 1] = "  " .. line
  end

  -- Write to buffer
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Store layout metadata
  layout_meta.snippet_offset = snippet_offset
  layout_meta.snippet_end = snippet_end

  -- Apply highlights (layout namespace)
  vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)

  highlight.apply_line_highlight(buf, 0, 1, "VimTeacherTitle")
  highlight.apply_line_highlight(buf, desc_start, desc_end, "VimTeacherHint")

  -- Separators
  highlight.apply_line_highlight(buf, snippet_offset - 3, snippet_offset - 2, "VimTeacherSeparator")
  highlight.apply_line_highlight(buf, progress_line, progress_line + 1, "VimTeacherProgress")
  highlight.apply_line_highlight(buf, snippet_offset - 1, snippet_offset, "VimTeacherSeparator")

  -- Bottom separator + hints
  highlight.apply_line_highlight(buf, snippet_end + 2, snippet_end + 3, "VimTeacherSeparator")
  highlight.apply_line_highlight(buf, hint_start, hint_start + #opts.hint_lines, "VimTeacherHint")
end

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

  -- Title
  lines[#lines + 1] = "  " .. opts.title
  lines[#lines + 1] = ""

  -- Description (abbreviated)
  for _, line in ipairs(opts.description) do
    lines[#lines + 1] = "  " .. line
  end
  lines[#lines + 1] = ""

  -- Separator + Progress (completed) + Separator
  lines[#lines + 1] = "  " .. SEPARATOR
  local completed = opts.progress
  local remaining = opts.max_progress - completed
  local bar = string.rep("#", completed) .. string.rep(".", remaining)
  lines[#lines + 1] = string.format("  Challenge %d/%d   [%s]", opts.progress, opts.max_progress, bar)
  lines[#lines + 1] = "  " .. SEPARATOR
  lines[#lines + 1] = ""

  -- Stats display
  lines[#lines + 1] = "  CHALLENGE COMPLETE!"
  lines[#lines + 1] = ""

  local best_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
  lines[#lines + 1] = string.format("  Time:      %.1fs        Best: %s", opts.time_secs, best_str)

  local avg_str = opts.avg_time and string.format("%.1fs", opts.avg_time) or "--"
  lines[#lines + 1] = string.format("  Speed:     %d%%          (vs your avg of %s)", opts.speed_pct, avg_str)

  lines[#lines + 1] = string.format(
    "  Accuracy:  %d%%          (%d moves / %d optimal)",
    opts.accuracy_pct,
    opts.actual_moves,
    opts.optimal_moves
  )

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. SEPARATOR
  lines[#lines + 1] = ""

  -- Write to buffer
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Apply highlights
  vim.api.nvim_buf_clear_namespace(buf, highlight.ns_layout, 0, -1)
  vim.api.nvim_buf_clear_namespace(buf, highlight.ns_target, 0, -1)

  highlight.apply_line_highlight(buf, 0, 1, "VimTeacherTitle")

  -- Find the "CHALLENGE COMPLETE!" line and highlight it
  for i, line in ipairs(lines) do
    if line:find("CHALLENGE COMPLETE!") then
      highlight.apply_line_highlight(buf, i - 1, i, "VimTeacherComplete")
    end
  end
end

--- Render the final completion screen for a lesson with session stats summary.
--- @param buf number Buffer handle
--- @param opts table Completion options
---   opts.title: string (lesson title)
---   opts.max_challenges: number (total challenges completed)
---   opts.session_challenges: table[] (list of {time, accuracy_pct, moves, optimal})
---   opts.best_time: number|nil (personal best from persistent stats)
---   opts.avg_time: number|nil (running average from persistent stats)
function M.render_completion(buf, opts)
  -- Compute aggregated session stats
  local total_time = 0
  local total_moves = 0
  local total_optimal = 0

  for _, c in ipairs(opts.session_challenges or {}) do
    total_time = total_time + c.time
    total_moves = total_moves + c.moves
    total_optimal = total_optimal + c.optimal
  end

  local num_challenges = #(opts.session_challenges or {})
  local avg_time = num_challenges > 0 and (total_time / num_challenges) or 0
  local overall_accuracy = total_moves > 0
    and math.floor((total_optimal / total_moves) * 100)
    or 100

  local lines = {
    "",
    "  LESSON COMPLETE!",
    "",
    "  " .. opts.title,
    "  You completed all " .. opts.max_challenges .. " challenges.",
    "",
    "  " .. SEPARATOR,
    "  Session Summary",
    "  " .. SEPARATOR,
    "",
  }

  local pb_str = opts.best_time and string.format("%.1fs", opts.best_time) or "--"
  lines[#lines + 1] = string.format(
    "  Total time:     %-12sPersonal best:  %s",
    string.format("%.1fs", total_time), pb_str
  )

  -- Speed %: session total vs historical avg session time (>100% = faster than usual)
  local speed_pct = 100
  if opts.avg_time and opts.avg_time > 0 and total_time > 0 then
    speed_pct = math.min(math.floor((opts.avg_time / total_time) * 100), 999)
  end
  local avg_hist_str = opts.avg_time and string.format("%.1fs", opts.avg_time) or "--"
  lines[#lines + 1] = string.format(
    "  Avg/challenge:  %-12sSpeed: %d%% (vs avg of %s)",
    string.format("%.1fs", avg_time), speed_pct, avg_hist_str
  )

  lines[#lines + 1] = string.format(
    "  Accuracy:       %-12s(%d moves / %d optimal)",
    string.format("%d%%", overall_accuracy), total_moves, total_optimal
  )

  lines[#lines + 1] = ""
  lines[#lines + 1] = "  " .. SEPARATOR
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
  lines[#lines + 1] = "  " .. SEPARATOR
  lines[#lines + 1] = ""

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  -- Apply highlights
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

--- Get the snippet zone boundaries from the last render.
--- @return number snippet_offset 0-indexed first line of snippet
--- @return number snippet_end 0-indexed last line of snippet
function M.get_snippet_bounds()
  return layout_meta.snippet_offset, layout_meta.snippet_end
end

return M
