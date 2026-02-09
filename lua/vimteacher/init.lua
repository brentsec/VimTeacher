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
local clear_stats_keymaps, clear_completion_keymaps

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
}

-- ─── Cleanup ───────────────────────────────────────────────────────────────

local function cleanup()
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
  local modify_keys = { "d", "dd", "D", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
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
--- @param allowed string[] Keys to leave unblocked (e.g., {"i", "a"})
local function block_keys_for_insert_lesson(allowed)
  local buf = state.buf
  local opts = { buffer = buf, noremap = true, silent = true }

  -- Build lookup of allowed keys
  local allowed_set = {}
  for _, key in ipairs(allowed) do
    allowed_set[key] = true
  end

  -- Block insert-mode entry keys that are NOT allowed
  local insert_keys = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
  for _, key in ipairs(insert_keys) do
    if not allowed_set[key] then
      vim.keymap.set("n", key, function()
        vim.notify("VimTeacher: Use " .. table.concat(allowed, " or ") .. " for this lesson", vim.log.levels.WARN)
      end, opts)
    else
      -- Remove any previous blocking keymap so the key works natively
      pcall(vim.keymap.del, "n", key, { buffer = buf })
    end
  end

  -- Block text-modifying keys silently
  local modify_keys = { "d", "dd", "D", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
  for _, key in ipairs(modify_keys) do
    vim.keymap.set("n", key, "<Nop>", opts)
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

  -- Number keys for topic selection
  local all_lessons = lessons.get_all()
  for i, lesson_info in ipairs(all_lessons) do
    if i <= 9 then -- support up to 9 topics
      vim.keymap.set("n", tostring(i), function()
        start_lesson(lesson_info.name)
      end, opts)
    end
  end

  -- Quit from menu
  vim.keymap.set("n", "q", function()
    cleanup()
  end, opts)
end

local function clear_menu_keymaps()
  local buf = state.buf
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local opts = { buffer = buf }
  for i = 1, 9 do
    pcall(vim.keymap.del, "n", tostring(i), opts)
  end
  pcall(vim.keymap.del, "n", "q", opts)
end

local function show_menu()
  state.mode = "menu"
  state.target = nil

  if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
    state.buf, state.win = buffer.create()
    setup_autocmds()
    block_insert_keys()
  end

  -- Clear any playing keymaps
  local all_lessons = lessons.get_all()
  buffer.render_menu(state.buf, all_lessons, state.all_stats)
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

-- ─── Playing mode ──────────────────────────────────────────────────────────

local function on_target_reached()
  -- Stop timer
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

  -- Read current snippet zone from buffer
  local actual = vim.api.nvim_buf_get_lines(
    state.buf, state.snippet_offset, state.snippet_end + 1, false
  )

  -- Compare to expected
  local expected = state.current_challenge.expected_lines
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
    vim.api.nvim_buf_set_lines(
      state.buf, state.snippet_offset, state.snippet_end + 1, false,
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

local function on_cursor_moved()
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
    goal = challenge.key and {
      action = challenge.key == "i" and "insert" or "append",
      char = challenge.char,
      key = challenge.key,
      preposition = challenge.key == "i" and "before cursor" or "after cursor",
    } or nil,
  })

  -- Get snippet boundaries
  state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()

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

  -- Apply appropriate key blocking for this lesson type
  -- (always re-apply; keymaps may be stale from a previous lesson or menu)
  if lesson.type == "insert" then
    block_keys_for_insert_lesson(lesson.allowed_keys or {})
  else
    block_insert_keys()
  end

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
