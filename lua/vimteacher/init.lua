-- vimteacher/init.lua
-- Main orchestrator: session lifecycle, state machine, autocmds, keymaps

local buffer = require("vimteacher.buffer")
local highlight = require("vimteacher.highlight")
local highlight_plan = require("vimteacher.highlight_plan")
local validate = require("vimteacher.validate")
local stats_mod = require("vimteacher.stats")
local lessons = require("vimteacher.lessons")
local snippets = require("vimteacher.snippets")
local keymaps = require("vimteacher.keymaps")

local M = {}

local DEFAULT_CONFIG = {
	keymaps = {
		mode = "adaptive_display", -- strict | adaptive_display | adaptive_runtime
		distro = "auto",
		overrides = {},
	},
}

local GLOBAL_ADAPTIVE_KEYS = {
	"h",
	"j",
	"k",
	"l",
	"w",
	"e",
	"b",
	"W",
	"E",
	"B",
	"0",
	"$",
	"_",
	"f",
	"F",
	"t",
	"T",
	";",
	"i",
	"a",
	"I",
	"A",
	"o",
	"O",
	"x",
	"r",
	"cl",
	"cw",
	"cW",
	"dw",
	"dW",
	"dd",
	"dj",
	"dk",
	"d2j",
	"d2k",
	"D",
	"yy",
	"p",
	"P",
	"gg",
	"G",
	"{",
	"}",
	"n",
	"N",
	"*",
	"#",
	"<C-u>",
	"<C-d>",
	"v",
	"V",
	".",
}

-- Forward declarations for local functions referenced before definition
local load_challenge, setup_autocmds, start_lesson, render_current_challenge
local clear_stats_keymaps, clear_completion_keymaps, clear_info_keymaps
local clear_playing_keymaps, rerender_menu_layout
local on_text_changed

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
	target = nil, -- {row, col} snippet-relative, or nil
	snippet_offset = 0,
	snippet_end = 0,
	move_count = 0,
	timer_start = nil, -- nil until first move
	optimal_moves = 0,
	all_stats = {},
	mode = "menu", -- "menu", "playing", "stats", "complete"
	current_challenge = nil, -- stores current challenge data for stats
	session_challenges = {}, -- list of {time, accuracy_pct, moves, optimal} per challenge
	dwell_pending = false, -- true while a dwell timer is running
	original_snippet = nil, -- stored for restore on failed insert edit
	total_buf_lines = nil, -- buffer line count at render time (for o/O restore)
	elapsed_timer = nil, -- repeating vim timer ID for display
	insert_validate_timer = nil, -- delayed validation timer while macro record/replay is active
	challenge_load_time = nil, -- hrtime when challenge was loaded
	pending_programmatic_cursor = nil, -- one synthetic CursorMoved position to ignore after render
	saved_inccommand = nil, -- user's original inccommand option, restored on cleanup
	play_menu_key = "q", -- per-lesson playing-mode key to return to menu
	play_restart_key = "Q", -- per-lesson playing-mode key to restart current lesson
	config = nil, -- merged plugin config for this session
	key_display = nil, -- resolved display keys for this session
	lesson_view = nil, -- resolved lesson text blocks (title/description/hints/goal)
}

-- ─── Helpers ──────────────────────────────────────────────────────────────

--- Normalize spaces immediately inside bracket pairs for tolerant matching.
--- Strips whitespace after ( [ { and before ) ] }.
local function normalize_bracket_spaces(line)
	line = line:gsub("([{%[%(])%s+", "%1")
	line = line:gsub("%s+([}%]%)])", "%1")
	return line
end

local function merged_config()
	local stored = vim.g.vimteacher_config
	if type(stored) ~= "table" then
		stored = {}
	end
	return vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_CONFIG), stored)
end

local function escape_lua_pattern(s)
	return s:gsub("(%W)", "%%%1")
end

local function is_word_char(ch)
	return type(ch) == "string" and ch:match("[%w_]") ~= nil
end

local function prev_nonspace_char(text, idx)
	for i = idx, 1, -1 do
		local ch = text:sub(i, i)
		if ch ~= " " and ch ~= "\t" then
			return ch
		end
	end
	return nil
end

local function next_nonspace_char(text, idx)
	for i = idx, #text do
		local ch = text:sub(i, i)
		if ch ~= " " and ch ~= "\t" then
			return ch
		end
	end
	return nil
end

local function replace_single_alpha_token(text, canonical, display)
	local escaped = escape_lua_pattern(canonical)
	return (text:gsub("()" .. escaped .. "()", function(start_pos, end_pos)
		local prev_char = start_pos > 1 and text:sub(start_pos - 1, start_pos - 1) or nil
		local next_char = end_pos <= #text and text:sub(end_pos, end_pos) or nil
		if is_word_char(prev_char) or is_word_char(next_char) then
			return canonical
		end

		local prev_nonspace = prev_nonspace_char(text, start_pos - 1)
		local next_nonspace = next_nonspace_char(text, end_pos)
		local prev_ok = prev_nonspace == nil or prev_nonspace:match("[%[%(%{:,/]") ~= nil
		local next_ok = next_nonspace == nil or next_nonspace:match("[%],:/=%)%}]") ~= nil
		if prev_ok and next_ok then
			return display
		end

		return canonical
	end))
end

local function apply_key_display_to_text(text, key_display)
	if type(text) ~= "string" then
		return text
	end
	if type(key_display) ~= "table" then
		return text
	end

	local keys = {}
	for canonical, _ in pairs(key_display) do
		keys[#keys + 1] = canonical
	end
	table.sort(keys, function(a, b)
		return #a > #b
	end)

	local out = text
	for _, canonical in ipairs(keys) do
		local display = key_display[canonical]
		if type(display) == "string" and display ~= "" and display ~= canonical then
			local escaped = escape_lua_pattern(canonical)
			out = out:gsub("%[" .. escaped .. "%]", "[" .. display .. "]")
			local single_alpha = canonical:match("^[%a]$") ~= nil
			if single_alpha then
				out = replace_single_alpha_token(out, canonical, display)
			elseif canonical:match("^[%w]+$") then
				out = out:gsub("(%f[%w])" .. escaped .. "(%f[^%w])", display)
			end
		end
	end
	return out
end

local function apply_key_display_to_lines(lines, key_display)
	if type(lines) ~= "table" then
		return lines
	end
	local out = {}
	for i, line in ipairs(lines) do
		out[i] = apply_key_display_to_text(line, key_display)
	end
	return out
end

local function lesson_ctx()
	return {
		key_display = state.key_display or {},
	}
end

local function build_lesson_view(lesson)
	local ctx = lesson_ctx()
	local view = {
		title = apply_key_display_to_text(lesson.title, ctx.key_display),
		description = apply_key_display_to_lines(lesson.description, ctx.key_display),
		hint_lines = apply_key_display_to_lines(lesson.hint_lines, ctx.key_display),
		goal_text = apply_key_display_to_text(lesson.goal_text, ctx.key_display),
		sandbox_snippet = vim.deepcopy(lesson.sandbox_snippet),
	}

	if type(lesson.get_title) == "function" then
		local ok, title = pcall(lesson.get_title, ctx)
		if ok and type(title) == "string" and title ~= "" then
			view.title = title
		end
	end

	if type(lesson.get_description) == "function" then
		local ok, lines = pcall(lesson.get_description, ctx)
		if ok and type(lines) == "table" then
			view.description = lines
		end
	end

	if type(lesson.get_hint_lines) == "function" then
		local ok, lines = pcall(lesson.get_hint_lines, ctx)
		if ok and type(lines) == "table" then
			view.hint_lines = lines
		end
	end

	if type(lesson.get_goal_text) == "function" then
		local ok, text = pcall(lesson.get_goal_text, ctx)
		if ok and type(text) == "string" and text ~= "" then
			view.goal_text = text
		end
	end

	if type(lesson.get_sandbox_snippet) == "function" then
		local ok, lines = pcall(lesson.get_sandbox_snippet, ctx)
		if ok and type(lines) == "table" then
			view.sandbox_snippet = lines
		end
	end

	return view
end

--- Build goal bar metadata from a challenge key/char.
--- @param key string|nil canonical key
--- @param char string|nil
--- @param display_key string|nil resolved display key
--- @return table|nil
local function build_goal(key, char, display_key)
	if not key then
		return nil
	end
	local g = { key = display_key or key, char = char }
	if key == "i" then
		g.action, g.preposition = "insert", "before cursor"
	elseif key == "a" then
		g.action, g.preposition = "append", "after cursor"
	elseif key == "I" then
		g.action, g.preposition = "insert", "at line start"
	elseif key == "A" then
		g.action, g.preposition = "append", "at line end"
	elseif key == "o" then
		g.action, g.preposition = "open below", "and type"
	elseif key == "O" then
		g.action, g.preposition = "open above", "and type"
	elseif key == "cl" then
		g.action, g.preposition = "change letter", "under cursor"
	elseif key == "x" then
		g.action, g.preposition = "delete", "under cursor"
	elseif key:match("^%d+x$") then
		g.action, g.preposition = "delete", key:sub(1, -2) .. " chars at cursor"
	elseif key == "r" then
		g.action, g.preposition = "replace with", "under cursor"
	elseif key == "." then
		g.action, g.preposition = "repeat last change", "at cursor"
	elseif key:match("^%d+%.$") then
		g.action, g.preposition = "repeat last change", key:sub(1, -2) .. " times"
	elseif key == "cw" then
		g.action, g.preposition = "change word to", "at cursor"
	elseif key == "cW" then
		g.action, g.preposition = "change WORD to", "at cursor"
	-- Delete operators
	elseif key == "dw" then
		g.action, g.preposition = "delete word", "at cursor"
	elseif key == "dW" then
		g.action, g.preposition = "delete WORD", "at cursor"
	elseif key == "dd" then
		g.action, g.preposition = "delete", "entire line"
	elseif key == "D" then
		g.action, g.preposition = "delete to", "end of line"
	elseif key:match("^d%d*j$") then
		g.action, g.preposition = "delete lines", "downward"
	elseif key:match("^d%d*k$") then
		g.action, g.preposition = "delete lines", "upward"
	-- Paste
	elseif key == "p" then
		g.action, g.preposition = "paste", "below current line"
	elseif key == "P" then
		g.action, g.preposition = "paste", "above current line"
	-- Text objects: change inside/around
	elseif key:match("^ci") then
		g.action, g.preposition = "change inside " .. key:sub(3), "at cursor"
	elseif key:match("^ca") then
		g.action, g.preposition = "change around " .. key:sub(3), "at cursor"
	-- Text objects: delete inside/around
	elseif key:match("^di") then
		g.action, g.preposition = "delete inside " .. key:sub(3), "at cursor"
	elseif key:match("^da") then
		g.action, g.preposition = "delete around " .. key:sub(3), "at cursor"
	-- Visual mode
	elseif key:match("^V.*c$") then
		g.action, g.preposition = "visual line change to", "selected lines"
	elseif key:match("^V.*d$") then
		g.action, g.preposition = "visual line delete", "selected lines"
	elseif key == "vd" then
		g.action, g.preposition = "visual delete", "selected text"
	elseif key == "vc" then
		g.action, g.preposition = "visual change to", "selected text"
	elseif key:match("^v.*d$") then
		g.action, g.preposition = "visual delete", "selected text"
	elseif key:match("^v.*c$") then
		g.action, g.preposition = "visual change to", "selected text"
	else
		return nil
	end
	return g
end

local function apply_phase(challenge, phase_idx)
	local phase = challenge and challenge.phases and challenge.phases[phase_idx]
	if not phase then
		return false
	end
	challenge.phase_index = phase_idx
	challenge.target = { row = phase.target.row, col = phase.target.col }
	challenge.key = phase.key
	challenge.char = phase.char
	challenge.goal_text = phase.goal_text
	challenge.target_end_col = phase.target_end_col
	if phase.start_pos then
		challenge.start_pos = { row = phase.start_pos.row, col = phase.start_pos.col }
	end
	challenge.expected_lines = vim.deepcopy(phase.expected_lines or challenge.expected_lines)
	return true
end

-- ─── Cleanup ───────────────────────────────────────────────────────────────

local function cleanup()
	-- Stop elapsed display timer
	if state.elapsed_timer then
		vim.fn.timer_stop(state.elapsed_timer)
	end
	if state.insert_validate_timer then
		vim.fn.timer_stop(state.insert_validate_timer)
		state.insert_validate_timer = nil
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
	state.insert_validate_timer = nil
	state.challenge_load_time = nil
	state.pending_programmatic_cursor = nil
	state.play_menu_key = "q"
	state.play_restart_key = "Q"
	state.key_display = nil
	state.lesson_view = nil
	state.config = nil
	if state.saved_inccommand ~= nil then
		vim.o.inccommand = state.saved_inccommand
		state.saved_inccommand = nil
	end
end

-- ─── Key blocking ──────────────────────────────────────────────────────────

local function to_set(keys)
	local s = {}
	for _, k in ipairs(keys or {}) do
		if type(k) == "string" and k ~= "" then
			s[k] = true
		end
	end
	return s
end

local function resolved_keys_for_lesson(lesson)
	local out = {}
	local seen = {}
	for _, canonical in ipairs((lesson and lesson.adaptive_keys) or {}) do
		local display = (state.key_display and state.key_display[canonical]) or canonical
		if type(display) == "string" and display ~= "" and not seen[display] then
			seen[display] = true
			out[#out + 1] = display
		end
	end
	return out
end

local function resolve_keys_list(canonical_keys)
	local out = {}
	local seen = {}
	for _, canonical in ipairs(canonical_keys or {}) do
		local display = (state.key_display and state.key_display[canonical]) or canonical
		if type(display) == "string" and display ~= "" and not seen[display] then
			seen[display] = true
			out[#out + 1] = display
		end
	end
	return out
end

local function block_insert_keys(exempt_keys)
	local buf = state.buf
	local opts = { buffer = buf, noremap = true, silent = true }
	local exempt = to_set(exempt_keys)

	-- Block insert-mode entry keys with a friendly message
	local insert_keys = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
	for _, key in ipairs(insert_keys) do
		if exempt[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, function()
				vim.notify("VimTeacher: Insert mode disabled during tutorial", vim.log.levels.WARN)
			end, opts)
		end
	end

	-- Block text-modifying keys silently
	local modify_keys = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
	for _, key in ipairs(modify_keys) do
		if exempt[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	-- Block visual mode
	local visual_keys = { "v", "V", "<C-v>" }
	for _, key in ipairs(visual_keys) do
		if exempt[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	-- Block mouse clicks (prevent bypassing keyboard navigation)
	local mouse_keys = {
		"<LeftMouse>",
		"<2-LeftMouse>",
		"<3-LeftMouse>",
		"<4-LeftMouse>",
		"<RightMouse>",
		"<2-RightMouse>",
		"<MiddleMouse>",
		"<ScrollWheelUp>",
		"<ScrollWheelDown>",
		"<ScrollWheelLeft>",
		"<ScrollWheelRight>",
	}
	for _, key in ipairs(mouse_keys) do
		vim.keymap.set("n", key, "<Nop>", opts)
	end
end

--- Block keys for insert-type lessons: allows specified insert keys, blocks the rest.
--- @param allowed string[] Insert keys to leave unblocked (e.g., {"i", "a"})
--- @param allowed_modify string[]|nil Modify keys to leave unblocked (e.g., {"x", "r"})
local function block_keys_for_insert_lesson(allowed, allowed_modify, allowed_visual)
	local buf = state.buf
	local opts = { buffer = buf, noremap = true, silent = true }

	-- Build lookup of allowed insert keys
	local allowed_set = {}
	for _, key in ipairs(allowed) do
		allowed_set[key] = true
		-- Clear stale local blockers so user/global remaps still work.
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end

	-- Build lookup of allowed modify keys
	local modify_allowed_set = {}
	for _, key in ipairs(allowed_modify or {}) do
		modify_allowed_set[key] = true
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end

	-- Build notification message with all allowed keys
	local all_allowed = {}
	for _, key in ipairs(allowed) do
		all_allowed[#all_allowed + 1] = key
	end
	for _, key in ipairs(allowed_modify or {}) do
		all_allowed[#all_allowed + 1] = key
	end
	local hint_msg = "VimTeacher: Use " .. table.concat(all_allowed, ", ") .. " for this lesson"

	-- Block insert-mode entry keys that are NOT allowed
	local insert_keys = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
	for _, key in ipairs(insert_keys) do
		if not allowed_set[key] then
			vim.keymap.set("n", key, function()
				vim.notify(hint_msg, vim.log.levels.WARN)
			end, opts)
		else
			-- Let built-in/user mappings pass through cleanly.
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		end
	end

	-- Block text-modifying keys that are NOT in allowed_modify
	local modify_keys = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
	for _, key in ipairs(modify_keys) do
		if modify_allowed_set[key] or allowed_set[key] then
			-- Remove any stale buffer-local map so the built-in command works cleanly.
			-- Don't re-map (e.g. d→d noremap); buffer-local mappings for operators
			-- interfere with operator-pending text objects like di{, da[, etc.
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		elseif #key > 1 and (modify_allowed_set[key:sub(1, 1)] or allowed_set[key:sub(1, 1)]) then
			-- Clean up multi-char variants (e.g. "dd" when "d" is allowed) to avoid
			-- mapping ambiguity in Neovim's key resolver.
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	-- Block visual mode (unless allowed by lesson)
	local visual_allowed_set = {}
	for _, key in ipairs(allowed_visual or {}) do
		visual_allowed_set[key] = true
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end

	local visual_keys = { "v", "V", "<C-v>" }
	for _, key in ipairs(visual_keys) do
		if visual_allowed_set[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	-- Block mouse clicks
	local mouse_keys = {
		"<LeftMouse>",
		"<2-LeftMouse>",
		"<3-LeftMouse>",
		"<4-LeftMouse>",
		"<RightMouse>",
		"<2-RightMouse>",
		"<MiddleMouse>",
		"<ScrollWheelUp>",
		"<ScrollWheelDown>",
		"<ScrollWheelLeft>",
		"<ScrollWheelRight>",
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
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local opts = { buffer = buf }
	for i = 0, 9 do
		pcall(vim.keymap.del, "n", tostring(i), opts)
	end
	pcall(vim.keymap.del, "n", "q", opts)
end

rerender_menu_layout = function()
	if state.mode ~= "menu" then
		return
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	if not state.win or not vim.api.nvim_win_is_valid(state.win) then
		return
	end

	local cursor = vim.api.nvim_win_get_cursor(state.win)
	local ok = pcall(buffer.render_menu, state.buf, lessons.get_sections(), state.all_stats, state.win)
	if not ok then
		return
	end

	local line_count = vim.api.nvim_buf_line_count(state.buf)
	local row = math.max(1, math.min(cursor[1], line_count))
	vim.api.nvim_win_set_cursor(state.win, { row, 0 })
	vim.fn.winrestview({ leftcol = 0 })
end

local function show_menu()
	if state.elapsed_timer then
		vim.fn.timer_stop(state.elapsed_timer)
		state.elapsed_timer = nil
	end
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
	local ok = pcall(buffer.render_menu, state.buf, all_sections, state.all_stats, state.win)
	if not ok then
		return
	end
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		-- Reset inherited scroll from prior screens so menu always starts at top.
		vim.fn.winrestview({ topline = 1, leftcol = 0 })
		vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
	end
	setup_menu_keymaps()
end

-- ─── Stats mode (between challenges) ──────────────────────────────────────

clear_stats_keymaps = function()
	local buf = state.buf
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	pcall(vim.keymap.del, "n", "<Space>", { buffer = buf })
end

-- ─── Playing mode keymaps (menu return + restart) ─────────────────────────

local function setup_playing_keymaps()
	local buf = state.buf
	local opts = { buffer = buf, noremap = true, silent = true }
	local menu_key = state.play_menu_key or "q"
	local restart_key = state.play_restart_key or "Q"

	vim.keymap.set("n", menu_key, function()
		show_menu()
	end, opts)

	vim.keymap.set("n", restart_key, function()
		start_lesson(state.lesson_name)
	end, opts)
end

clear_playing_keymaps = function()
	local buf = state.buf
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local opts = { buffer = buf }
	pcall(vim.keymap.del, "n", state.play_menu_key or "q", opts)
	pcall(vim.keymap.del, "n", state.play_restart_key or "Q", opts)
	pcall(vim.keymap.del, "n", "q", opts)
	pcall(vim.keymap.del, "n", "Q", opts)
	pcall(vim.keymap.del, "n", "m", opts)
	pcall(vim.keymap.del, "n", "R", opts)
	pcall(vim.keymap.del, "n", "gg", opts)
	pcall(vim.keymap.del, "n", "G", opts)
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
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local opts = { buffer = buf }
	for _, key in ipairs({ "n", "p", "r", "m", "q" }) do
		pcall(vim.keymap.del, "n", key, opts)
	end
end

clear_info_keymaps = function()
	local buf = state.buf
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	pcall(vim.keymap.del, "n", "n", { buffer = buf })
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
	if not state.challenge_load_time then
		return
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
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

	-- Estimated optimal can be beaten when users chain advanced motions that a
	-- lesson's heuristic model doesn't fully cover. Clamp per-challenge optimal
	-- for scoring/display so summaries stay internally consistent.
	local scored_optimal = stats_mod.normalize_optimal_moves(state.optimal_moves, state.move_count)

	-- Accumulate session stats for end-of-lesson summary
	local accuracy_pct = stats_mod.calc_accuracy_pct(scored_optimal, state.move_count)
	state.session_challenges[#state.session_challenges + 1] = {
		time = elapsed,
		accuracy_pct = accuracy_pct,
		moves = state.move_count,
		optimal = scored_optimal,
	}

	-- Flash success
	local target_buf_row = state.target.row + state.snippet_offset
	highlight.flash_success(state.buf, target_buf_row, state.target.col)

	-- Nullify target to prevent double-triggers
	state.target = nil
	state.mode = "stats"

	-- After flash, auto-progress to next challenge or show completion
	vim.defer_fn(function()
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end

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
			local overall_accuracy = stats_mod.calc_overall_accuracy_pct(total_optimal, total_moves)

			-- Record session in persistent stats
			local ls = stats_mod.record_session(state.all_stats, state.lesson_name, total_time, overall_accuracy)
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

--- @param expected string[]
--- @return boolean
local function snippet_matches_expected(expected)
	if not expected or not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return false
	end
	local actual = vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_offset + #expected, false)

	local match = #actual == #expected
	if match then
		for i = 1, #expected do
			if actual[i] ~= expected[i] then
				match = false
				break
			end
		end
	end

	-- Fallback: tolerate spaces immediately inside brackets
	if not match and #actual == #expected then
		local norm_match = true
		for i = 1, #expected do
			if normalize_bracket_spaces(actual[i]) ~= normalize_bracket_spaces(expected[i]) then
				norm_match = false
				break
			end
		end
		if norm_match then
			match = true
		end
	end

	return match
end

local function restore_original_snippet()
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	if not state.original_snippet or not state.current_challenge then
		return
	end

	local rel_cursor = nil
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		local cur = vim.api.nvim_win_get_cursor(state.win)
		rel_cursor = { row = cur[1] - 1 - state.snippet_offset, col = cur[2] }
	end

	-- Re-render the full challenge layout so style + semantic highlights are restored,
	-- even if an incorrect substitute touched instruction/goal lines.
	render_current_challenge(rel_cursor)
	vim.notify("Not quite — try again!", vim.log.levels.INFO)
end

--- Render current challenge UI + target highlight.
--- @param cursor_rel table|nil optional snippet-relative cursor {row,col}
render_current_challenge = function(cursor_rel)
	local challenge = state.current_challenge
	if not challenge then
		return
	end
	local view = state.lesson_view or build_lesson_view(state.lesson)
	local goal_text = challenge.goal_text or view.goal_text
	goal_text = apply_key_display_to_text(goal_text, state.key_display or {})
	local goal_display_key = (state.key_display and state.key_display[challenge.key]) or challenge.key

	state.loading = true

	buffer.render(state.buf, {
		title = view.title,
		description = view.description,
		progress = state.challenge_num,
		max_progress = state.max_challenges,
		snippet_lines = challenge.snippet_lines,
		hint_lines = view.hint_lines,
		goal_text = goal_text,
		goal = build_goal(challenge.key, challenge.char, goal_display_key),
		nav_hint_line = string.format(
			"[%s] Menu  [%s] Restart lesson",
			state.play_menu_key or "q",
			state.play_restart_key or "Q"
		),
	})

	state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()
	state.total_buf_lines = vim.api.nvim_buf_line_count(state.buf)
	state.target = challenge.target

	if challenge.highlight_rows then
		local buf_rows = {}
		for _, r in ipairs(challenge.highlight_rows) do
			buf_rows[#buf_rows + 1] = r + state.snippet_offset
		end
		highlight.place_target_rows(state.buf, buf_rows)
		if challenge.paste_marker_after_row ~= nil then
			highlight.place_paste_marker(state.buf, challenge.paste_marker_after_row + state.snippet_offset)
		end
	else
		challenge._highlight_plan = highlight_plan.compute_for_challenge(challenge)
		local target_buf_row = state.target.row + state.snippet_offset
		local hl_group = challenge.search_word and "VimTeacherSearchTarget" or nil
		local plan = challenge._highlight_plan
		local hl_col = state.target.col
		local target_end_col = nil
		local full_line = false
		if plan then
			hl_col = plan.start_col or hl_col
			target_end_col = plan.end_col
			full_line = plan.full_line
		end
		highlight.place_target(state.buf, target_buf_row, hl_col, target_end_col, full_line, hl_group)
	end

	local desired = cursor_rel or challenge.start_pos or { row = 0, col = 0 }
	local max_row = math.max(0, (#challenge.snippet_lines or 1) - 1)
	local row = math.max(0, math.min(desired.row or 0, max_row))
	local line = challenge.snippet_lines[row + 1] or ""
	local col = math.max(0, math.min(desired.col or 0, #line))
	vim.api.nvim_win_set_cursor(state.win, { row + state.snippet_offset + 1, col })
	state.pending_programmatic_cursor = { row = row + state.snippet_offset + 1, col = col }
	if state.challenge_num == 1 and not cursor_rel then
		-- Starting a lesson after a scrolled menu can inherit old view offsets.
		-- Force first challenge to render from the top of the lesson layout.
		vim.fn.winrestview({ topline = 1, leftcol = 0 })
	end

	if state.lesson.type == "insert" then
		state.original_snippet =
			vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_end + 1, false)
		vim.bo[state.buf].modifiable = true
	end

	if state.timer_start and state.challenge_load_time then
		local elapsed = (vim.loop.hrtime() - state.challenge_load_time) / 1e9
		buffer.update_timer(state.buf, elapsed)
	else
		buffer.update_timer(state.buf, 0)
	end

	state.loading = nil
end

--- Advance to next in-challenge phase when configured.
--- @return boolean advanced
local function advance_challenge_phase()
	local challenge = state.current_challenge
	if not challenge or not challenge.phases then
		return false
	end

	local current_idx = challenge.phase_index or 1
	local next_idx = current_idx + 1
	if not challenge.phases[next_idx] then
		return false
	end

	local cursor = vim.api.nvim_win_get_cursor(state.win)
	local rel_cursor = { row = cursor[1] - 1 - state.snippet_offset, col = cursor[2] }
	challenge.snippet_lines = vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_end + 1, false)
	if not apply_phase(challenge, next_idx) then
		return false
	end
	challenge._highlight_plan = nil
	render_current_challenge(rel_cursor)
	return true
end

local function on_insert_leave()
	if state.mode ~= "playing" then
		return
	end
	if not state.lesson or state.lesson.type ~= "insert" then
		return
	end
	if not state.current_challenge or not state.current_challenge.expected_lines then
		return
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end

	if snippet_matches_expected(state.current_challenge.expected_lines) then
		if not advance_challenge_phase() then
			on_target_reached()
		end
	else
		restore_original_snippet()
	end
end

local function macro_session_busy()
	return vim.fn.reg_recording() ~= "" or vim.fn.reg_executing() ~= ""
end

local function schedule_insert_validation_retry()
	if state.insert_validate_timer then
		return
	end
	state.insert_validate_timer = vim.fn.timer_start(25, function()
		state.insert_validate_timer = nil
		vim.schedule(function()
			if state.mode ~= "playing" then
				return
			end
			if not state.lesson or state.lesson.type ~= "insert" then
				return
			end
			if not state.lesson.allowed_modify_keys then
				return
			end
			if macro_session_busy() then
				schedule_insert_validation_retry()
				return
			end
			on_text_changed()
		end)
	end)
end

on_text_changed = function()
	if state.mode ~= "playing" then
		return
	end
	if state.loading then
		return
	end
	if not state.lesson or state.lesson.type ~= "insert" then
		return
	end
	-- Only process for lessons with Normal-mode modify keys (e.g., small_edits with x, r)
	if not state.lesson.allowed_modify_keys then
		return
	end
	if not state.current_challenge or not state.current_challenge.expected_lines then
		return
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	if macro_session_busy() then
		-- While recording/executing macros, intermediate text states are expected.
		-- Delay pass/fail validation until macro activity has fully settled.
		schedule_insert_validation_retry()
		return
	end

	if snippet_matches_expected(state.current_challenge.expected_lines) then
		if not advance_challenge_phase() then
			on_target_reached()
		end
		return
	end

	-- Check if text is already the original (avoid double-restore from InsertLeave + TextChanged)
	local orig = state.original_snippet
	local actual = vim.api.nvim_buf_get_lines(
		state.buf,
		state.snippet_offset,
		state.snippet_offset + #(state.current_challenge.expected_lines or {}),
		false
	)
	if orig then
		local is_orig = #actual == #orig
		if is_orig then
			for i = 1, #orig do
				if actual[i] ~= orig[i] then
					is_orig = false
					break
				end
			end
		end
		if is_orig then
			return
		end
	end

	restore_original_snippet()
end

--- Check if cursor is on the target position.
--- Uses row-only matching when challenge.row_only_check is true (e.g., gg/G lessons).
local function is_on_target()
	local target_buf_row = state.target.row + state.snippet_offset
	if state.current_challenge and state.current_challenge.row_only_check then
		local cursor = vim.api.nvim_win_get_cursor(state.win)
		return (cursor[1] - 1) == target_buf_row
	else
		return validate.check_position(state.win, target_buf_row, state.target.col)
	end
end

local function on_cursor_moved()
	-- Info lessons: constrain cursor to snippet zone only (no move counting)
	if state.mode == "info" then
		validate.constrain_to_snippet(state.win, state.snippet_offset, state.snippet_end)
		return
	end

	-- Only active in playing mode
	if state.mode ~= "playing" then
		return
	end
	if state.loading then
		return
	end
	if not state.target then
		return
	end
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	if not state.win or not vim.api.nvim_win_is_valid(state.win) then
		return
	end

	-- Ignore one synthetic event emitted at the programmatically positioned start cursor.
	if state.pending_programmatic_cursor then
		local cur = vim.api.nvim_win_get_cursor(state.win)
		local p = state.pending_programmatic_cursor
		state.pending_programmatic_cursor = nil
		if cur[1] == p.row and cur[2] == p.col then
			return
		end
	end

	-- Constrain cursor to snippet zone
	local was_constrained = validate.constrain_to_snippet(state.win, state.snippet_offset, state.snippet_end)

	-- Start timer on first real user move.
	if not state.timer_start then
		state.timer_start = vim.loop.hrtime()
		start_elapsed_timer()
	end

	if was_constrained then
		-- Normally, constrained moves are boundary bounces (don't count as moves).
		-- But absolute jumps (gg/G) overshoot the snippet and get constrained back
		-- to the boundary — which IS the target row. Check if we landed on target.
		if state.lesson and state.lesson.type ~= "insert" and is_on_target() then
			state.move_count = state.move_count + 1
			on_target_reached()
		end
		return
	end

	-- Count the move (only non-constrained moves count for accuracy)
	state.move_count = state.move_count + 1

	-- Insert lessons: don't trigger completion on cursor position;
	-- success is validated via InsertLeave instead
	if state.lesson and state.lesson.type == "insert" then
		return
	end

	-- Check target match with dwell-time validation (50ms)
	-- Prevents completing by holding a key and flying past the target
	if is_on_target() then
		if not state.dwell_pending then
			state.dwell_pending = true
			vim.defer_fn(function()
				state.dwell_pending = false
				if state.mode ~= "playing" then
					return
				end
				if not state.target then
					return
				end
				if not state.win or not vim.api.nvim_win_is_valid(state.win) then
					return
				end
				-- Re-verify cursor is still on target after dwell period
				if is_on_target() then
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
	if challenge.phases then
		apply_phase(challenge, 1)
	end
	state.current_challenge = challenge

	-- Compute optimal moves for this challenge
	local start = challenge.start_pos or { row = 0, col = 0 }
	if state.lesson.compute_optimal then
		state.optimal_moves = state.lesson.compute_optimal(start, challenge.target, challenge)
	else
		-- Default: Manhattan distance
		state.optimal_moves = math.abs(start.row - challenge.target.row) + math.abs(start.col - challenge.target.col)
	end

	render_current_challenge()
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

	-- Visual mode exit: schedule validation after buffer state settles
	vim.api.nvim_create_autocmd("ModeChanged", {
		group = state.augroup,
		pattern = "[vV\x16]*:n*",
		callback = function()
			if vim.api.nvim_get_current_buf() ~= state.buf then
				return
			end
			vim.schedule(on_text_changed)
		end,
	})

	vim.api.nvim_create_autocmd("BufWipeout", {
		group = state.augroup,
		buffer = state.buf,
		callback = function()
			cleanup()
		end,
	})

	vim.api.nvim_create_autocmd({ "WinResized", "VimResized" }, {
		group = state.augroup,
		callback = function()
			rerender_menu_layout()
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
	state.play_menu_key = lesson.play_menu_key or "q"
	state.play_restart_key = lesson.play_restart_key or "Q"
	state.lesson_view = build_lesson_view(lesson)

	-- Ensure buffer exists
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		state.buf, state.win = buffer.create()
		setup_autocmds()
	end

	-- Remap gg/G to snippet-relative jumps
	-- (prevents cursor escaping to buffer header/footer; reads state at keypress time)
	local nav_opts = { buffer = state.buf, noremap = true, silent = true }
	local top_jump_key = (state.key_display and state.key_display["gg"]) or "gg"
	local bottom_jump_key = (state.key_display and state.key_display["G"]) or "G"
	for _, key in ipairs({ "gg", top_jump_key }) do
		pcall(vim.keymap.del, "n", key, { buffer = state.buf })
	end
	for _, key in ipairs({ "G", bottom_jump_key }) do
		pcall(vim.keymap.del, "n", key, { buffer = state.buf })
	end
	vim.keymap.set("n", top_jump_key, function()
		if state.snippet_offset and state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_set_cursor(state.win, { state.snippet_offset + 1, 0 })
		end
	end, nav_opts)
	vim.keymap.set("n", bottom_jump_key, function()
		if state.snippet_end and state.win and vim.api.nvim_win_is_valid(state.win) then
			vim.api.nvim_win_set_cursor(state.win, { state.snippet_end + 1, 0 })
		end
	end, nav_opts)

	-- Info lessons: display description + sandbox, no challenges
	if lesson.type == "info" then
		state.mode = "info"
		local info_exempt_keys = resolved_keys_for_lesson(lesson)
		info_exempt_keys[#info_exempt_keys + 1] = "i"
		local resolved_insert = (state.key_display and state.key_display["i"]) or nil
		if type(resolved_insert) == "string" and resolved_insert ~= "" then
			info_exempt_keys[#info_exempt_keys + 1] = resolved_insert
		end
		block_insert_keys(info_exempt_keys)
		-- Unblock sandbox modify keys for info lesson free practice
		if lesson.sandbox_modify_keys then
			local sandbox_keys = resolve_keys_list(lesson.sandbox_modify_keys)
			for _, key in ipairs(sandbox_keys) do
				pcall(vim.keymap.del, "n", key, { buffer = state.buf })
			end
		end
		-- Render layout (no progress bar)
		buffer.render(state.buf, {
			title = state.lesson_view.title,
			description = state.lesson_view.description,
			snippet_lines = state.lesson_view.sandbox_snippet or lesson.sandbox_snippet,
			hint_lines = state.lesson_view.hint_lines,
		})
		state.snippet_offset, state.snippet_end = buffer.get_snippet_bounds()
		vim.bo[state.buf].modifiable = true
		vim.bo[state.buf].undolevels = 1000
		-- Start at the instruction block so step-by-step text is visible on smaller windows.
		-- Users can move into the sandbox right below to practice.
		local info_start_row = math.min(vim.api.nvim_buf_line_count(state.buf), 3)
		vim.api.nvim_win_set_cursor(state.win, { info_start_row, 0 })
		vim.fn.winrestview({ topline = 1, leftcol = 0 })
		-- Navigation keymaps
		local opts = { buffer = state.buf, noremap = true, silent = true }
		vim.keymap.set("n", "n", function()
			local next_name = lessons.get_next(lesson_name)
			if next_name then
				start_lesson(next_name)
			end
		end, opts)
		vim.keymap.set("n", "q", function()
			show_menu()
		end, opts)
		return
	end

	-- Apply appropriate key blocking for this lesson type
	-- (always re-apply; keymaps may be stale from a previous lesson or menu)
	if lesson.type == "insert" then
		block_keys_for_insert_lesson(
			resolve_keys_list(lesson.allowed_keys or {}),
			resolve_keys_list(lesson.allowed_modify_keys),
			resolve_keys_list(lesson.allowed_visual_keys)
		)
		-- Ensure autoindent for o/O lessons (new lines inherit current line's indent)
		vim.bo[state.buf].autoindent = true
	else
		block_insert_keys(resolved_keys_for_lesson(lesson))
	end

	-- Set up navigation keymaps for playing mode
	setup_playing_keymaps()

	-- Load first challenge
	load_challenge()
end

-- ─── Public API ────────────────────────────────────────────────────────────

--- Configure VimTeacher behavior.
--- @param opts table|nil
function M.setup(opts)
	vim.g.vimteacher_config = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_CONFIG), opts or {})
end

--- Start VimTeacher. Shows the topic menu.
--- @param lesson_name string|nil Optional lesson name to jump directly into
function M.start(lesson_name)
	-- Clean up existing session
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		cleanup()
	end

	-- Initialize highlight groups
	highlight.setup()

	-- Disable live :substitute preview while tutoring to avoid commandline text
	-- visually leaking into instructions/goal bars during typing.
	if state.saved_inccommand == nil then
		state.saved_inccommand = vim.o.inccommand
	end
	if vim.o.inccommand ~= "" then
		vim.o.inccommand = ""
	end

	state.config = merged_config()
	keymaps.configure(state.config.keymaps)
	state.key_display = nil
	if keymaps.is_adaptive_mode() then
		keymaps.capture()
		keymaps.capture_deferred()
		local diagnostics
		state.key_display, diagnostics = keymaps.resolve_many(GLOBAL_ADAPTIVE_KEYS)
		if diagnostics and #diagnostics.custom > 0 then
			local preview = {}
			for i = 1, math.min(8, #diagnostics.custom) do
				preview[#preview + 1] = diagnostics.custom[i]
			end
			local suffix = (#diagnostics.custom > 8) and ", ..." or ""
			vim.notify(
				"VimTeacher adaptive keymaps (" .. table.concat(preview, ", ") .. suffix .. ")",
				vim.log.levels.INFO
			)
		end
	end

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

-- Exposed for testing
M._normalize_bracket_spaces = normalize_bracket_spaces

return M
