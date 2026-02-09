-- vimteacher/init.lua
-- Main orchestrator: session lifecycle, state machine, autocmds, keymaps

local buffer = require("vimteacher.buffer")
local highlight = require("vimteacher.highlight")
local validate = require("vimteacher.validate")
local stats_mod = require("vimteacher.stats")
local lessons = require("vimteacher.lessons")
local snippets = require("vimteacher.snippets")

local M = {}

-- Forward declarations for local functions referenced before definition
local load_challenge, setup_autocmds, start_lesson
local clear_stats_keymaps, clear_completion_keymaps, clear_info_keymaps
local clear_playing_keymaps

-- Menu input timer (module-level for cleanup access)
local menu_input_timer = nil

-- Session state (singleton — one session at a time)
local state = {
  buf = nil,
  win = nil,
  augroup = nil,
  lesson = nil,
  lesson_name = nil,
  challenge_num = 0,
  max_challenges = 10,
  target = nil,           -- {row, col} snippet-relative, or nil
  snippet_offset = 0,
  snippet_end = 0,
  move_count = 0,
  timer_start = nil,      -- nil until first move
  optimal_moves = 0,
  all_stats = {},
  mode = "menu",          -- "menu", "playing", "stats", "complete"
  current_challenge = nil, -- stores current challenge data for stats
  session_challenges = {}, -- list of {time, accuracy_pct, moves, optimal} per challenge
  dwell_pending = false,   -- true while a dwell timer is running
  original_snippet = nil,  -- stored for restore on failed insert edit
  total_buf_lines = nil,   -- buffer line count at render time (for o/O restore)
  elapsed_timer = nil,        -- repeating vim timer ID for display
  challenge_load_time = nil,  -- hrtime when challenge was loaded
}

-- ─── Cleanup ───────────────────────────────────────────────────────────────

local function cleanup()
  -- Stop elapsed display timer
  if state.elapsed_timer then
    vim.fn.timer_stop(state.elapsed_timer)
  end

  if state.augroup then
    pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
    state.augroup = nil
  end

  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
  end

  state.buf = nil
  state.win = nil
  state.target = nil
  state.lesson = nil
  state.lesson_name = nil
  state.challenge_num = 0
  state.snippet_offset = 0
  state.snippet_end = 0
  state.move_count = 0
  state.timer_start = nil
  state.optimal_moves = 0
  state.mode = "menu"
  state.current_challenge = nil
  state.session_challenges = {}
  state.dwell_pending = false
  state.original_snippet = nil
  state.total_buf_lines = nil
  state.elapsed_timer = nil
  state.challenge_load_time = nil
end

-- ─── Key blocking ──────────────────────────────────────────────────────────

local function block_insert_keys()
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Block insert-mode entry keys with a friendly message
  local insert_keys = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
  for _, key in ipairs(insert_keys) do
    vim.keymap.set("n", key, function()
      vim.notify("VimTeacher: Insert mode disabled during tutorial", vim.log.levels.WARN)
    end, opts)
  end

  -- Block text-modifying keys silently
  local modify_keys = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
  for _, key in ipairs(modify_keys) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end

  -- Block visual mode
  local visual_keys = { "v", "V", "<C-v>" }
  for _, key in ipairs(visual_keys) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end

  -- Block mouse clicks (prevent bypassing keyboard navigation)
  local mouse_keys = {
    "<LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>",
    "<RightMouse>", "<2-RightMouse>",
    "<MiddleMouse>",
    "<ScrollWheelUp>", "<ScrollWheelDown>",
    "<ScrollWheelLeft>", "<ScrollWheelRight>",
  }
  for _, key in ipairs(mouse_keys) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end
end

--- Block keys for insert-type lessons: allows specified insert keys, blocks the rest.
--- @param allowed string[] Insert keys to leave unblocked (e.g., {"i", "a"})
--- @param allowed_modify string[]|nil Modify keys to leave unblocked (e.g., {"x", "r"})
local function block_keys_for_insert_lesson(allowed, allowed_modify)
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Build lookup of allowed insert keys
  local allowed_set = {}
  for _, key in ipairs(allowed) do
    allowed_set[key] = true
  end

  -- Build lookup of allowed modify keys
  local modify_allowed_set = {}
  for _, key in ipairs(allowed_modify or {}) do
    modify_allowed_set[key] = true
  end

  -- Build notification message with all allowed keys
  local all_allowed = {}
  for _, key in ipairs(allowed) do all_allowed[#all_allowed + 1] = key end
  for _, key in ipairs(allowed_modify or {}) do all_allowed[#all_allowed + 1] = key end
  local hint_msg = "VimTeacher: Use " .. table.concat(all_allowed, ", ") .. " for this lesson"

  -- Block insert-mode entry keys that are NOT allowed
  local insert_keys = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
  for _, key in ipairs(insert_keys) do
    if not allowed_set[key] then
      vim.keymap.set("n", key, function()
        vim.notify(hint_msg, vim.log.levels.WARN)
      end, opts)
    else
      -- Map allowed key to its native command (noremap) to override global plugin keymaps
      vim.keymap.set("n", key, key, opts)
    end
  end

  -- Block text-modifying keys that are NOT in allowed_modify
  local modify_keys = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
  for _, key in ipairs(modify_keys) do
    if modify_allowed_set[key] then
      -- Map allowed key to its native command (noremap) to override global plugin keymaps
      vim.keymap.set("n", key, key, opts)
    else
      vim.keymap.set("n", key, "<Nop>", opts)
    end
  end

  -- Block visual mode
  local visual_keys = { "v", "V", "<C-v>" }
  for _, key in ipairs(visual_keys) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end

  -- Block mouse clicks
  local mouse_keys = {
    "<LeftMouse>", "<2-LeftMouse>", "<3-LeftMouse>", "<4-LeftMouse>",
    "<RightMouse>", "<2-RightMouse>",
    "<MiddleMouse>",
    "<ScrollWheelUp>", "<ScrollWheelDown>",
    "<ScrollWheelLeft>", "<ScrollWheelRight>",
  }
  for _, key in ipairs(mouse_keys) do
    vim.keymap.set("n", key, "<Nop>", opts)
  end
end

-- ─── Menu mode ─────────────────────────────────────────────────────────────

local function setup_menu_keymaps()
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }
  local all_lessons = lessons.get_all()
  local total = #all_lessons
  local input_buf = ""

  local function flush_input()
    if menu_input_timer then
      vim.fn.timer_stop(menu_input_timer)
      menu_input_timer = nil
    end
    local num = tonumber(input_buf)
    input_buf = ""
    if num and num >= 1 and num <= total then
      start_lesson(all_lessons[num].name)
    end
  end

  local function handle_digit(d)
    if menu_input_timer then
      vim.fn.timer_stop(menu_input_timer)
      menu_input_timer = nil
    end
    input_buf = input_buf .. tostring(d)
    local num = tonumber(input_buf)

    -- Check if appending any digit 0-9 could yield a valid lesson number
    local could_extend = false
    if num then
      for ext = num * 10, num * 10 + 9 do
        if ext >= 1 and ext <= total then
          could_extend = true
          break
        end
      end
    end

    if not could_extend then
      flush_input()
    else
      menu_input_timer = vim.fn.timer_start(800, function()
        vim.schedule(function()
          flush_input()
        end)
      end)
    end
  end

  -- Map digit keys 1-9
  for d = 1, 9 do
    vim.keymap.set("n", tostring(d), function()
      handle_digit(d)
    end, opts)
  end

  -- Map 0 only as a continuation digit (ignored when input_buf is empty)
  vim.keymap.set("n", "0", function()
    if input_buf ~= "" then
      handle_digit(0)
    end
  end, opts)

  -- Quit from menu
  vim.keymap.set("n", "q", function()
    if menu_input_timer then
      vim.fn.timer_stop(menu_input_timer)
      menu_input_timer = nil
    end
    input_buf = ""
    cleanup()
  end, opts)
end

local function clear_menu_keymaps()
  if menu_input_timer then
    vim.fn.timer_stop(menu_input_timer)
    menu_input_timer = nil
  end
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local opts = { buffer = buf }
  for i = 0, 9 do
    pcall(vim.keymap.del, "n", tostring(i), opts)
  end
  pcall(vim.keymap.del, "n", "q", opts)
end

local function show_menu()
  state.mode = "menu"
  state.target = nil
  clear_info_keymaps()
  clear_playing_keymaps()

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf, state.win = buffer.create()
    setup_autocmds()
    block_insert_keys()
  end

  -- Clear any playing keymaps
  local all_sections = lessons.get_sections()
  buffer.render_menu(state.buf, all_sections, state.all_stats)
  setup_menu_keymaps()
end

-- ─── Stats mode (between challenges) ──────────────────────────────────────

local function setup_stats_keymaps()
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }

  vim.keymap.set("n", "<Space>", function()
    clear_stats_keymaps()
    load_challenge()
  end, opts)
end

clear_stats_keymaps = function()
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  pcall(vim.keymap.del, "n", "<Space>", { buffer = buf })
end

-- ─── Playing mode keymaps (menu return + restart) ─────────────────────────

local function setup_playing_keymaps()
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }

  vim.keymap.set("n", "q", function()
    show_menu()
  end, opts)

  vim.keymap.set("n", "Q", function()
    start_lesson(state.lesson_name)
  end, opts)
end

clear_playing_keymaps = function()
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local opts = { buffer = buf }
  pcall(vim.keymap.del, "n", "q", opts)
  pcall(vim.keymap.del, "n", "Q", opts)
end

-- ─── Completion mode ───────────────────────────────────────────────────────

local function setup_completion_keymaps()
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }

  vim.keymap.set("n", "n", function()
    local next_name = lessons.get_next(state.lesson_name)
    if next_name then
      start_lesson(next_name)
    else
      vim.notify("VimTeacher: No more topics available.", vim.log.levels.INFO)
    end
  end, opts)

  vim.keymap.set("n", "p", function()
    local prev_name = lessons.get_prev(state.lesson_name)
    if prev_name then
      start_lesson(prev_name)
    else
      vim.notify("VimTeacher: Already at the first topic.", vim.log.levels.INFO)
    end
  end, opts)

  vim.keymap.set("n", "r", function()
    start_lesson(state.lesson_name)
  end, opts)

  vim.keymap.set("n", "m", function()
    clear_completion_keymaps()
    show_menu()
  end, opts)

  vim.keymap.set("n", "q", function()
    cleanup()
  end, opts)
end

clear_completion_keymaps = function()
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local opts = { buffer = buf }
  for _, key in ipairs({ "n", "p", "r", "m", "q" }) do
    pcall(vim.keymap.del, "n", key, opts)
  end
end

clear_info_keymaps = function()
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  pcall(vim.keymap.del, "n", "<CR>", { buffer = buf })
  pcall(vim.keymap.del, "n", "q", { buffer = buf })
end

-- ─── Elapsed timer display ────────────────────────────────────────────────

local function stop_elapsed_timer()
  if state.elapsed_timer then
    vim.fn.timer_stop(state.elapsed_timer)
    state.elapsed_timer = nil
  end
end

local function update_timer_display()
  if not state.challenge_load_time then return end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  local elapsed = (vim.loop.hrtime() - state.challenge_load_time) / 1e9
  buffer.update_timer(state.buf, elapsed)
end

local function start_elapsed_timer()
  stop_elapsed_timer()
  state.challenge_load_time = vim.loop.hrtime()
  -- Show initial 00:00
  buffer.update_timer(state.buf, 0)
  -- Update every second
  state.elapsed_timer = vim.fn.timer_start(1000, function()
    vim.schedule(update_timer_display)
  end, { ["repeat"] = -1 })
end

-- ─── Playing mode ──────────────────────────────────────────────────────────

local function on_target_reached()
  -- Stop elapsed display timer
  stop_elapsed_timer()

  -- Stop scoring timer
  local elapsed = 0
  if state.timer_start then
    elapsed = vim.loop.hrtime() - state.timer_start
    elapsed = elapsed / 1e9 -- convert to seconds
  end

  -- Accumulate session stats for end-of-lesson summary
  local accuracy_pct = stats_mod.calc_accuracy_pct(state.optimal_moves, state.move_count)
  state.session_challenges[#state.session_challenges + 1] = {
    time = elapsed,
    accuracy_pct = accuracy_pct,
    moves = state.move_count,
    optimal = state.optimal_moves,
  }

  -- Flash success
  local target_buf_row = state.target.row + state.snippet_offset
  highlight.flash_success(state.buf, target_buf_row, state.target.col)

  -- Nullify target to prevent double-triggers
  state.target = nil
  state.mode = "stats"

  -- After flash, auto-progress to next challenge or show completion
  vim.defer_fn(function()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

    if state.challenge_num >= state.max_challenges then
      -- Compute session totals
      local total_time = 0
      local total_moves = 0
      local total_optimal = 0
      for _, c in ipairs(state.session_challenges) do
        total_time = total_time + c.time
        total_moves = total_moves + c.moves
        total_optimal = total_optimal + c.optimal
      end
      local overall_accuracy = total_moves > 0
        and math.floor((total_optimal / total_moves) * 100) or 100

      -- Record session in persistent stats
      local ls = stats_mod.record_session(
        state.all_stats, state.lesson_name, total_time, overall_accuracy
      )
      stats_mod.save(state.all_stats)

      -- Show completion screen with session summary
      state.mode = "complete"
      buffer.render_completion(state.buf, {
        title = state.lesson.title,
        max_challenges = state.max_challenges,
        session_challenges = state.session_challenges,
        best_time = ls.best_time,
        avg_time = ls.avg_time,
      })
      setup_completion_keymaps()
    else
      -- Auto-progress to next challenge
      load_challenge()
    end
  end, 300)
end

local function on_insert_leave()
  if state.mode ~= "playing" then return end
  if not state.lesson or state.lesson.type ~= "insert" then return end
  if not state.current_challenge or not state.current_challenge.expected_lines then return end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  -- Read current snippet zone from buffer (use expected length for o/O compatibility)
  local expected = state.current_challenge.expected_lines
  local actual = vim.api.nvim_buf_get_lines(
    state.buf, state.snippet_offset, state.snippet_offset + #expected, false
  )
  local match = #actual == #expected
  if match then
    for i = 1, #expected do
      if actual[i] ~= expected[i] then match = false; break end
    end
  end

  if match then
    on_target_reached()
  else
    -- Restore original snippet and let user try again
    vim.bo[state.buf].modifiable = true
    local extra = vim.api.nvim_buf_line_count(state.buf) - (state.total_buf_lines or 0)
    if extra < 0 then extra = 0 end
    vim.api.nvim_buf_set_lines(
      state.buf, state.snippet_offset, state.snippet_end + extra + 1, false,
      state.original_snippet
    )
    -- Re-place target highlight
    if state.target then
      local target_buf_row = state.target.row + state.snippet_offset
      highlight.place_target(state.buf, target_buf_row, state.target.col)
    end
    vim.notify("Not quite — try again!", vim.log.levels.INFO)
  end
end

local function on_text_changed()
  if state.mode ~= "playing" then return end
  if not state.lesson or state.lesson.type ~= "insert" then return end
  -- Only process for lessons with Normal-mode modify keys (e.g., small_edits with x, r)
  if not state.lesson.allowed_modify_keys then return end
  if not state.current_challenge or not state.current_challenge.expected_lines then return end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

  local expected = state.current_challenge.expected_lines
  local actual = vim.api.nvim_buf_get_lines(
    state.buf, state.snippet_offset, state.snippet_offset + #expected, false
  )

  local match = #actual == #expected
  if match then
    for i = 1, #expected do
      if actual[i] ~= expected[i] then match = false; break end
    end
  end

  if match then
    on_target_reached()
    return
  end

  -- Check if text is already the original (avoid double-restore from InsertLeave + TextChanged)
  local orig = state.original_snippet
  if orig then
    local is_orig = #actual == #orig
    if is_orig then
      for i = 1, #orig do
        if actual[i] ~= orig[i] then is_orig = false; break end
      end
    end
    if is_orig then return end
  end

  -- Restore original snippet
  vim.bo[state.buf].modifiable = true
  local extra = vim.api.nvim_buf_line_count(state.buf) - (state.total_buf_lines or 0)
  if extra < 0 then extra = 0 end
  vim.api.nvim_buf_set_lines(
    state.buf, state.snippet_offset, state.snippet_end + extra + 1, false,
    state.original_snippet
  )
  -- Re-place target highlight
  if state.target then
    local target_buf_row = state.target.row + state.snippet_offset
    highlight.place_target(state.buf, target_buf_row, state.target.col)
  end
  vim.notify("Not quite — try again!", vim.log.levels.INFO)
end

local function on_cursor_moved()
  -- Info lessons: constrain cursor to snippet zone only (no move counting)
  if state.mode == "info" then
    validate.constrain_to_snippet(state.win, state.snippet_offset, state.snippet_end)
    return
  end

  -- Only active in playing mode
  if state.mode ~= "playing" then return end
  if not state.target then return end
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end

  -- Constrain cursor to snippet zone
  local was_constrained = validate.constrain_to_snippet(
    state.win, state.snippet_offset, state.snippet_end
  )

  -- Start timer on first move (even if constrained — user is actively playing)
  if not state.timer_start then
    state.timer_start = vim.loop.hrtime()
  end

  if was_constrained then return end

  -- Count the move (only non-constrained moves count)
  state.move_count = state.move_count + 1

  -- Insert lessons: don't trigger completion on cursor position;
  -- success is validated via InsertLeave instead
  if state.lesson and state.lesson.type == "insert" then
    return
  end

  -- Check target match with dwell-time validation (50ms)
  -- Prevents completing by holding a key and flying past the target
  local target_buf_row = state.target.row + state.snippet_offset
  if validate.check_position(state.win, target_buf_row, state.target.col) then
    if not state.dwell_pending then
      state.dwell_pending = true
      vim.defer_fn(function()
        state.dwell_pending = false
        if state.mode ~= "playing" then return end
        if not state.target then return end
        if not state.win or not vim.api.nvim_win_is_valid(state.win) then return end
        -- Re-verify cursor is still on target after dwell period
        local tbr = state.target.row + state.snippet_offset
        if validate.check_position(state.win, tbr, state.target.col) then
          on_target_reached()
        end
      end, state.lesson.dwell_time or 50)
    end
  else
    -- Cursor moved off target — allow new dwell timer on next landing
    state.dwell_pending = false
  end
end

load_challenge = function()
  state.challenge_num = state.challenge_num + 1
  state.mode = "playing"
  state.move_count = 0
  state.timer_start = nil
  state.dwell_pending = false

  -- Generate a fresh challenge
  local challenge = state.lesson.generate_challenge(state.buf, highlight.ns_target)
  state.current_challenge = challenge

  -- Compute optimal moves for this challenge
  local start = challenge.start_pos or { row = 0, col = 0 }
  if state.lesson.compute_optimal then
    state.optimal_moves = state.lesson.compute_optimal(start, challenge.target)
  else
    -- Default: Manhattan distance
    state.optimal_moves = math.abs(start.row - challenge.target.row)
      + math.abs(start.col - challenge.target.col)
  end

  -- Render the lesson layout
  buffer.render(state.buf, {
    title = state.lesson.title,
    description = state.lesson.description,
    progress = state.challenge_num,
    max_progress = state.max_challenges,
    snippet_lines = challenge.snippet_lines,
    hint_lines = state.lesson.hint_lines,
    goal = (function()
      if not challenge.key then return nil end
      local k = challenge.key
      local g = { key = k, char = challenge.char }
      if k == "i" then
        g.action, g.preposition = "insert", "before cursor"
      elseif k == "a" then
        g.action, g.preposition = "append", "after cursor"
      elseif k == "I" then
        g.action, g.preposition = "insert", "at line start"
      elseif k == "A" then
        g.action, g.preposition = "append", "at line end"
      elseif k == "o" then
        g.action, g.preposition = "open below", "and type"
      elseif k == "O" then
        g.action, g.preposition = "open above", "and type"
      elseif k == "cl" then
        g.action, g.preposition = "change letter", "under cursor"
      elseif k == "x" then
        g.action, g.preposition = "delete", "under cursor"
      elseif k == "r" then
        g.action, g.preposition = "replace with", "under cursor"
      end
      return g
    end)(),
  })

  -- Get snippet boundaries
  state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()

  -- Store total buffer line count (needed for o/O restore when lines are added)
  state.total_buf_lines = vim.api.nvim_buf_line_count(state.buf)

  -- Store target
  state.target = challenge.target

  -- Place green target highlight
  local target_buf_row = state.target.row + state.snippet_offset
  highlight.place_target(state.buf, target_buf_row, state.target.col)

  -- Position cursor at start location
  local start_pos = challenge.start_pos or { row = 0, col = 0 }
  local buf_start_row = start_pos.row + state.snippet_offset
  vim.api.nvim_win_set_cursor(state.win, { buf_start_row + 1, start_pos.col })

  -- Insert lessons: store original snippet and enable editing
  if state.lesson.type == "insert" then
    state.original_snippet = vim.deepcopy(challenge.snippet_lines)
    vim.bo[state.buf].modifiable = true
  end

  -- Start elapsed timer display
  start_elapsed_timer()
end

setup_autocmds = function()
  state.augroup = vim.api.nvim_create_augroup("VimTeacher", { clear = true })

  vim.api.nvim_create_autocmd("CursorMoved", {
    group = state.augroup,
    buffer = state.buf,
    callback = on_cursor_moved,
  })

  vim.api.nvim_create_autocmd("InsertLeave", {
    group = state.augroup,
    buffer = state.buf,
    callback = on_insert_leave,
  })

  vim.api.nvim_create_autocmd("TextChanged", {
    group = state.augroup,
    buffer = state.buf,
    callback = on_text_changed,
  })

  vim.api.nvim_create_autocmd("BufWipeout", {
    group = state.augroup,
    buffer = state.buf,
    callback = function()
      cleanup()
    end,
  })
end

start_lesson = function(lesson_name)
  -- Clear any existing keymaps from previous mode
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    clear_menu_keymaps()
    clear_stats_keymaps()
    clear_completion_keymaps()
    clear_info_keymaps()
    clear_playing_keymaps()
  end

  local lesson = lessons.get_lesson(lesson_name)
  if not lesson then
    vim.notify("VimTeacher: Unknown lesson '" .. lesson_name .. "'", vim.log.levels.ERROR)
    return
  end

  -- Seed RNG
  math.randomseed(os.time() + math.floor(os.clock() * 1000))

  -- Reset snippet recency
  snippets.reset_recent()

  -- Store lesson state
  state.lesson = lesson
  state.lesson_name = lesson_name
  state.challenge_num = 0
  state.max_challenges = lesson.challenges_required or 10
  state.session_challenges = {}
  state.mode = "playing"

  -- Ensure buffer exists
  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf, state.win = buffer.create()
    setup_autocmds()
  end

  -- Info lessons: display description + sandbox, no challenges
  if lesson.type == "info" then
    state.mode = "info"
    block_insert_keys()
    -- Unblock 'i' for sandbox practice
    pcall(vim.keymap.del, "n", "i", { buffer = state.buf })
    -- Render layout (no progress bar)
    buffer.render(state.buf, {
      title = lesson.title,
      description = lesson.description,
      snippet_lines = lesson.sandbox_snippet,
      hint_lines = lesson.hint_lines,
    })
    state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_win_set_cursor(state.win, { state.snippet_offset + 1, 0 })
    -- Navigation keymaps
    local opts = { buffer = state.buf, noremap = true, silent = true }
    vim.keymap.set("n", "<CR>", function()
      local next_name = lessons.get_next(lesson_name)
      if next_name then start_lesson(next_name) end
    end, opts)
    vim.keymap.set("n", "q", function()
      show_menu()
    end, opts)
    return
  end

  -- Apply appropriate key blocking for this lesson type
  -- (always re-apply; keymaps may be stale from a previous lesson or menu)
  if lesson.type == "insert" then
    block_keys_for_insert_lesson(lesson.allowed_keys or {}, lesson.allowed_modify_keys)
    -- Ensure autoindent for o/O lessons (new lines inherit current line's indent)
    vim.bo[state.buf].autoindent = true
  else
    block_insert_keys()
  end

  -- Set up navigation keymaps (q=menu, Q=restart) for playing mode
  setup_playing_keymaps()

  -- Load first challenge
  load_challenge()
end

-- ─── Public API ────────────────────────────────────────────────────────────

--- Start VimTeacher. Shows the topic menu.
--- @param lesson_name string|nil Optional lesson name to jump directly into
function M.start(lesson_name)
  -- Clean up existing session
  if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
    cleanup()
  end

  -- Initialize highlight groups
  highlight.setup()

  -- Load persistent stats
  state.all_stats = stats_mod.load()

  if lesson_name and lesson_name ~= "" then
    -- Direct jump to a specific lesson
    state.buf, state.win = buffer.create()
    setup_autocmds()
    block_insert_keys()
    start_lesson(lesson_name)
  else
    -- Show topic menu
    state.buf, state.win = buffer.create()
    setup_autocmds()
    block_insert_keys()
    show_menu()
  end
end

return M
