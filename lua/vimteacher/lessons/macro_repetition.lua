-- vimteacher/lessons/macro_repetition.lua
-- Lesson: macros for repeated edits.

local M = {}
local optimal = require("vimteacher.optimal")

M.title = "Macros for Repetition: qa, q, @a, @@"
M.type = "insert"
M.play_menu_key = "m"
M.play_restart_key = "Q"
M.allowed_keys = {}
M.allowed_modify_keys = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
M.allowed_visual_keys = { "v", "V", "<C-v>" }
M.challenges_required = 10

M.description = {
	"Macros replay exact keystrokes, which is perfect for repeated edits.",
	"",
	"Core keys:",
	"  qa   start recording into register a",
	"  q    stop recording",
	"  @a   run macro from register a once",
	"  @@   repeat the most recently executed macro",
	"  10@a run macro in register a ten times",
	"",
	"Recommended workflow:",
	"1) Move to first green target.",
	"2) Press qa to start recording.",
	"3) Do only the edit (usually x in these challenges).",
	"4) Press q to stop recording BEFORE you move away.",
	"5) Move to next target and run @a / @@ / count@a.",
	"",
	"For multi-line repetition, record movement too (example: xj).",
	"That edit+move macro is what makes counted @a useful down a column.",
	"",
	"Tip: keep the recorded macro minimal so replay stays predictable.",
}

M.hint_lines = {
	"[qa] Record in a  [q] Stop recording  [@a] Run a  [@@] Repeat last macro  [count@a] Repeat N times",
}

local recent = {}
local MAX_RECENT = 5
local current_snippet = nil

--- @param line string
--- @param col number 0-indexed
--- @return string
local function delete_one(line, col)
	if col < 0 or col >= #line then
		return line
	end
	return line:sub(1, col) .. line:sub(col + 2)
end

--- @param line string
--- @param needle string
--- @param occurrence number
--- @return number|nil 1-indexed byte position
local function find_nth(line, needle, occurrence)
	local from = 1
	local occ = occurrence or 1
	for i = 1, occ do
		local s, e = line:find(needle, from, true)
		if not s then
			return nil
		end
		if i == occ then
			return s
		end
		from = e + 1
	end
	return nil
end

--- @param snippet string[]
--- @param target_def table {row,find,occurrence?,offset?}
--- @return table {row,col}
local function resolve_target(snippet, target_def)
	local line = snippet[(target_def.row or 0) + 1] or ""
	local s = find_nth(line, target_def.find, target_def.occurrence or 1)
	assert(s, "macro_repetition target find failed: " .. tostring(target_def.find))
	local col = (s - 1) + (target_def.offset or 0)
	assert(col >= 0 and col < #line, "macro_repetition target col out of bounds")
	return { row = target_def.row, col = col }
end

--- @param def table
--- @return table
local function build_challenge(def)
	local snippet = vim.deepcopy(def.snippet_lines)
	local targets = {}
	for _, t in ipairs(def.targets) do
		targets[#targets + 1] = resolve_target(snippet, t)
	end

	local states = {}
	local prev = vim.deepcopy(snippet)
	for i, t in ipairs(targets) do
		local next_lines = vim.deepcopy(prev)
		next_lines[t.row + 1] = delete_one(next_lines[t.row + 1], t.col)
		states[i] = next_lines
		prev = next_lines
	end

	local phases = {}
	local phase1_goal = def.record_goal or "From target: qa, do edit, then q (stop recording before moving)"
	if def.mode == "count" then
		phase1_goal = def.record_goal or "Record a line-step macro: qa, xj, q"
	end
	phases[1] = {
		target = { row = targets[1].row, col = targets[1].col },
		target_end_col = targets[1].col + 1,
		goal_text = phase1_goal,
		expected_lines = vim.deepcopy(states[1]),
	}

	if def.mode == "at_then_repeat" then
		assert(#targets >= 3, "at_then_repeat mode needs at least 3 targets")
		phases[2] = {
			target = { row = targets[2].row, col = targets[2].col },
			target_end_col = targets[2].col + 1,
			goal_text = "Run @a on this target",
			expected_lines = vim.deepcopy(states[2]),
		}
		phases[3] = {
			target = { row = targets[3].row, col = targets[3].col },
			target_end_col = targets[3].col + 1,
			goal_text = "Run @@ to repeat it one more time",
			expected_lines = vim.deepcopy(states[3]),
		}
	elseif def.mode == "single_at" then
		assert(#targets >= 2, "single_at mode needs at least 2 targets")
		phases[2] = {
			target = { row = targets[2].row, col = targets[2].col },
			target_end_col = targets[2].col + 1,
			goal_text = "Run @a on this target",
			expected_lines = vim.deepcopy(states[2]),
		}
	elseif def.mode == "count" then
		assert(#targets >= 2, "count mode needs at least 2 targets")
		local repeat_count = #targets - 1
		phases[2] = {
			target = { row = targets[2].row, col = targets[2].col },
			target_end_col = targets[2].col + 1,
			goal_text = string.format("Run %d@a on this target (counted macro repeat)", repeat_count),
			expected_lines = vim.deepcopy(states[#targets]),
		}
	else
		error("Unknown macro challenge mode: " .. tostring(def.mode))
	end

	local start_pos = def.start_pos or { row = targets[1].row, col = 0 }

	return {
		snippet_lines = snippet,
		expected_lines = vim.deepcopy(states[#targets]),
		target = { row = targets[1].row, col = targets[1].col },
		target_end_col = targets[1].col + 1,
		start_pos = { row = start_pos.row, col = start_pos.col },
		goal_text = phases[1].goal_text,
		phases = phases,
		_macro_targets = vim.deepcopy(targets),
	}
end

local CHALLENGE_DEFS = {
	{
		mode = "at_then_repeat",
		snippet_lines = {
			"function syncIds() {",
			"  const user__id = getUser();",
			"  const order__id = getOrder();",
			"  const cart__id = getCart();",
			"  return true;",
			"}",
		},
		targets = {
			{ row = 1, find = "__" },
			{ row = 2, find = "__" },
			{ row = 3, find = "__" },
		},
		start_pos = { row = 1, col = 0 },
	},
	{
		mode = "at_then_repeat",
		snippet_lines = {
			"function boot() {",
			"  initAlpha();;",
			"  initBeta();;",
			"  initGamma();;",
			"  return true;",
			"}",
		},
		targets = {
			{ row = 1, find = ";;" },
			{ row = 2, find = ";;" },
			{ row = 3, find = ";;" },
		},
		start_pos = { row = 1, col = 0 },
	},
	{
		mode = "single_at",
		snippet_lines = {
			"function writeLogs() {",
			"  log(user));",
			"  log(order));",
			"  return true;",
			"}",
		},
		targets = {
			{ row = 1, find = "));" },
			{ row = 2, find = "));" },
		},
		start_pos = { row = 1, col = 0 },
	},
	{
		mode = "count",
		snippet_lines = {
			"let key01__id = read01();",
			"let key02__id = read02();",
			"let key03__id = read03();",
			"let key04__id = read04();",
		},
		targets = {
			{ row = 0, find = "__" },
			{ row = 1, find = "__" },
			{ row = 2, find = "__" },
			{ row = 3, find = "__" },
		},
		start_pos = { row = 0, col = 0 },
	},
	{
		mode = "count",
		snippet_lines = {
			"let row01__id = one;",
			"let row02__id = two;",
			"let row03__id = three;",
			"let row04__id = four;",
			"let row05__id = five;",
			"let row06__id = six;",
		},
		targets = {
			{ row = 0, find = "__" },
			{ row = 1, find = "__" },
			{ row = 2, find = "__" },
			{ row = 3, find = "__" },
			{ row = 4, find = "__" },
			{ row = 5, find = "__" },
		},
		start_pos = { row = 0, col = 0 },
	},
	{
		mode = "at_then_repeat",
		snippet_lines = {
			"const hostA = 'api..local';",
			"const hostB = 'db..local';",
			"const hostC = 'cdn..local';",
			"return true;",
		},
		targets = {
			{ row = 0, find = ".." },
			{ row = 1, find = ".." },
			{ row = 2, find = ".." },
		},
		start_pos = { row = 0, col = 0 },
	},
	{
		mode = "single_at",
		snippet_lines = {
			"const first = build(a,, b);",
			"const second = build(c,, d);",
			"return true;",
		},
		targets = {
			{ row = 0, find = ",," },
			{ row = 1, find = ",," },
		},
		start_pos = { row = 0, col = 0 },
	},
	{
		mode = "at_then_repeat",
		snippet_lines = {
			"const routeA = '/v1//users';",
			"const routeB = '/v1//orders';",
			"const routeC = '/v1//carts';",
			"return true;",
		},
		targets = {
			{ row = 0, find = "//" },
			{ row = 1, find = "//" },
			{ row = 2, find = "//" },
		},
		start_pos = { row = 0, col = 0 },
	},
	{
		mode = "count",
		snippet_lines = {
			"let val01 = parseInt(raw01));",
			"let val02 = parseInt(raw02));",
			"let val03 = parseInt(raw03));",
			"return val01 + val02 + val03;",
		},
		targets = {
			{ row = 0, find = "));" },
			{ row = 1, find = "));" },
			{ row = 2, find = "));" },
		},
		start_pos = { row = 0, col = 0 },
	},
	{
		mode = "count",
		snippet_lines = {
			"let row01__id = 1;",
			"let row02__id = 2;",
			"let row03__id = 3;",
			"let row04__id = 4;",
			"let row05__id = 5;",
			"let row06__id = 6;",
			"let row07__id = 7;",
			"let row08__id = 8;",
			"let row09__id = 9;",
			"let row10__id = 10;",
			"let row11__id = 11;",
		},
		targets = {
			{ row = 0, find = "__" },
			{ row = 1, find = "__" },
			{ row = 2, find = "__" },
			{ row = 3, find = "__" },
			{ row = 4, find = "__" },
			{ row = 5, find = "__" },
			{ row = 6, find = "__" },
			{ row = 7, find = "__" },
			{ row = 8, find = "__" },
			{ row = 9, find = "__" },
			{ row = 10, find = "__" },
		},
		start_pos = { row = 0, col = 0 },
	},
}

local CHALLENGES = {}
for _, def in ipairs(CHALLENGE_DEFS) do
	CHALLENGES[#CHALLENGES + 1] = build_challenge(def)
end

local function manhattan(a, b)
	return math.abs(a.row - b.row) + math.abs(a.col - b.col)
end

--- Compute optimal movement cost for macro lesson phases.
--- @param start_pos table {row,col}
--- @param target table {row,col}
--- @param challenge table|nil
--- @return number
function M.compute_optimal(start_pos, target, challenge)
	if challenge and challenge.phases and #challenge.phases > 0 then
		local total = 0
		local pos = { row = start_pos.row, col = start_pos.col }
		local lines = challenge.snippet_lines
		for _, phase in ipairs(challenge.phases) do
			total = total + optimal.nav_cost(lines, pos, phase.target)
			lines = phase.expected_lines or lines
			pos = phase.target
		end
		return total
	end
	if not current_snippet then
		return manhattan(start_pos, target)
	end
	return optimal.nav_cost(current_snippet, start_pos, target)
end

--- @param _buf number
--- @param _ns_id number
--- @return table
function M.generate_challenge(_buf, _ns_id)
	local eligible = {}
	for i = 1, #CHALLENGES do
		local seen = false
		for _, r in ipairs(recent) do
			if r == i then
				seen = true
				break
			end
		end
		if not seen then
			eligible[#eligible + 1] = i
		end
	end

	if #eligible == 0 then
		recent = {}
		for i = 1, #CHALLENGES do
			eligible[#eligible + 1] = i
		end
	end

	local idx = eligible[math.random(1, #eligible)]
	recent[#recent + 1] = idx
	if #recent > MAX_RECENT then
		table.remove(recent, 1)
	end

	local c = CHALLENGES[idx]
	current_snippet = c.snippet_lines

	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		target_end_col = c.target_end_col,
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		goal_text = c.goal_text,
		phases = vim.deepcopy(c.phases),
		_macro_targets = vim.deepcopy(c._macro_targets),
	}
end

function M._get_challenges()
	return CHALLENGES
end

return M
