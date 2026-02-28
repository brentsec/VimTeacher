-- vimteacher/lessons/small_edits.lua
-- Seventh lesson: Character-level edits with cl, x, r

local M = {}

M.title = "Small Edits: cl, x, r"
M.type = "insert"
M.allowed_keys = { "c" }
M.allowed_modify_keys = { "x", "r" }
M.allowed_nav_keys = { "h", "j", "k", "l", "w", "b", "e" }
M.challenges_required = 10

M.description = {
	"Quick character-level edits without full insert mode:",
	"",
	"  x  = delete the character under the cursor",
	"  r  = replace character under cursor (type the replacement)",
	"  cl = change letter: delete char and enter insert mode",
	"",
	"Navigate to the green target and use the indicated key.",
}

M.hint_lines = {
	"[x] Delete char  [r] Replace char  [cl] Change letter  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool.
-- x: deletes the char at target — char field is the char being deleted (display only)
-- r: replaces the char at target with char field (single replacement char)
-- s: deletes the char at target, enters insert mode, user types char field (multi-char)
local CHALLENGES = {
	-- Challenge 1: x — delete extra 's' in 'conssole'
	{
		snippet_lines = {
			"function debug(msg) {",
			"  conssole.log(msg);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function debug(msg) {",
			"  console.log(msg);",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 6 },
		start_pos = { row = 3, col = 0 },
		key = "x",
		char = "s",
	},

	-- Challenge 2: x — delete extra 't' in 'retturn'
	{
		snippet_lines = {
			"function getResult() {",
			"  const value = compute();",
			"  retturn value;",
			"}",
		},
		expected_lines = {
			"function getResult() {",
			"  const value = compute();",
			"  return value;",
			"}",
		},
		target = { row = 2, col = 5 },
		start_pos = { row = 0, col = 0 },
		key = "x",
		char = "t",
	},

	-- Challenge 3: x — delete extra 't' in 'ittem'
	{
		snippet_lines = {
			"function process(records) {",
			"  const ittem = records[0];",
			"  return item.name;",
			"}",
		},
		expected_lines = {
			"function process(records) {",
			"  const item = records[0];",
			"  return item.name;",
			"}",
		},
		target = { row = 1, col = 10 },
		start_pos = { row = 3, col = 0 },
		key = "x",
		char = "t",
	},

	-- Challenge 4: r — replace 'a' with 'o' in 'functian'
	{
		snippet_lines = {
			"functian add(a, b) {",
			"  return a + b;",
			"}",
		},
		expected_lines = {
			"function add(a, b) {",
			"  return a + b;",
			"}",
		},
		target = { row = 0, col = 6 },
		start_pos = { row = 2, col = 0 },
		key = "r",
		char = "o",
	},

	-- Challenge 5: r — replace 'f' with 'g' in 'console.lof'
	{
		snippet_lines = {
			"function warn(msg) {",
			"  console.lof(msg);",
			"  return false;",
			"}",
		},
		expected_lines = {
			"function warn(msg) {",
			"  console.log(msg);",
			"  return false;",
			"}",
		},
		target = { row = 1, col = 12 },
		start_pos = { row = 0, col = 0 },
		key = "r",
		char = "g",
	},

	-- Challenge 6: r — replace 'r' with 't' in 'resulr'
	{
		snippet_lines = {
			"function fetchData(url) {",
			"  const resulr = fetch(url);",
			"  return JSON.parse(data);",
			"}",
		},
		expected_lines = {
			"function fetchData(url) {",
			"  const result = fetch(url);",
			"  return JSON.parse(data);",
			"}",
		},
		target = { row = 1, col = 13 },
		start_pos = { row = 3, col = 0 },
		key = "r",
		char = "t",
	},

	-- Challenge 7: r — replace 'n' with 'r' in 'retunn'
	{
		snippet_lines = {
			"function isValid(input) {",
			"  const check = input.length > 0;",
			"  retunn check;",
			"}",
		},
		expected_lines = {
			"function isValid(input) {",
			"  const check = input.length > 0;",
			"  return check;",
			"}",
		},
		target = { row = 2, col = 6 },
		start_pos = { row = 0, col = 0 },
		key = "r",
		char = "r",
	},

	-- Challenge 8: cl — replace 'X' with 'let'
	{
		snippet_lines = {
			"function init(config) {",
			"  X items = config.list;",
			"  return items;",
			"}",
		},
		expected_lines = {
			"function init(config) {",
			"  let items = config.list;",
			"  return items;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "cl",
		char = "let",
	},

	-- Challenge 9: cl — replace 'Z' with 'const'
	{
		snippet_lines = {
			"function setup() {",
			"  Z port = 3000;",
			"  return port;",
			"}",
		},
		expected_lines = {
			"function setup() {",
			"  const port = 3000;",
			"  return port;",
			"}",
		},
		target = { row = 1, col = 2 },
		start_pos = { row = 3, col = 0 },
		key = "cl",
		char = "const",
	},

	-- Challenge 10: cl — replace 'Y' with 'return'
	{
		snippet_lines = {
			"function sum(a, b) {",
			"  const total = a + b;",
			"  Y total;",
			"}",
		},
		expected_lines = {
			"function sum(a, b) {",
			"  const total = a + b;",
			"  return total;",
			"}",
		},
		target = { row = 2, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "cl",
		char = "return",
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5
local current_snippet = nil

local function manhattan(start_pos, target)
	return math.abs(start_pos.row - target.row) + math.abs(start_pos.col - target.col)
end

local function char_class(char)
	if not char or char == "" or char:match("%s") then
		return "space"
	elseif char:match("[%w_]") then
		return "word"
	else
		return "punct"
	end
end

local function build_tokens(lines)
	local tokens = {}
	for row_idx, line in ipairs(lines) do
		local col = 1
		while col <= #line do
			local cls = char_class(line:sub(col, col))
			if cls == "space" then
				col = col + 1
			else
				local start_col = col
				col = col + 1
				while col <= #line and char_class(line:sub(col, col)) == cls do
					col = col + 1
				end
				tokens[#tokens + 1] = {
					row = row_idx - 1,
					start_col = start_col - 1,
					end_col = col - 2,
				}
			end
		end
	end
	return tokens
end

local function line_len(lines, row)
	local line = lines[row + 1] or ""
	return #line
end

local function clamp_col(lines, row, col)
	local len = line_len(lines, row)
	if len <= 0 then
		return 0
	end
	if col < 0 then
		return 0
	end
	if col >= len then
		return len - 1
	end
	return col
end

local function pos_lt(a, b)
	return a.row < b.row or (a.row == b.row and a.col < b.col)
end

local function find_token_index(tokens, pos)
	for i, t in ipairs(tokens) do
		if t.row == pos.row and pos.col >= t.start_col and pos.col <= t.end_col then
			return i
		end
	end
	return nil
end

local function move_w(tokens, pos)
	local idx = find_token_index(tokens, pos)
	if idx then
		local next_token = tokens[idx + 1]
		if next_token then
			return { row = next_token.row, col = next_token.start_col }
		end
		return pos
	end

	for _, t in ipairs(tokens) do
		local start_pos = { row = t.row, col = t.start_col }
		if pos_lt(pos, start_pos) then
			return start_pos
		end
	end
	return pos
end

local function move_b(tokens, pos)
	local idx = find_token_index(tokens, pos)
	if idx then
		local cur = tokens[idx]
		if pos.col > cur.start_col then
			return { row = cur.row, col = cur.start_col }
		end
		local prev = tokens[idx - 1]
		if prev then
			return { row = prev.row, col = prev.start_col }
		end
		return pos
	end

	for i = #tokens, 1, -1 do
		local t = tokens[i]
		local start_pos = { row = t.row, col = t.start_col }
		if pos_lt(start_pos, pos) then
			return start_pos
		end
	end
	return pos
end

local function move_e(tokens, pos)
	local idx = find_token_index(tokens, pos)
	if idx then
		local cur = tokens[idx]
		if pos.col < cur.end_col then
			return { row = cur.row, col = cur.end_col }
		end
		local next_token = tokens[idx + 1]
		if next_token then
			return { row = next_token.row, col = next_token.end_col }
		end
		return pos
	end

	for _, t in ipairs(tokens) do
		local end_pos = { row = t.row, col = t.end_col }
		if pos_lt(pos, end_pos) then
			return end_pos
		end
	end
	return pos
end

local function apply_motion(lines, tokens, pos, motion)
	local row = pos.row
	local col = pos.col

	if motion == "h" then
		if col > 0 then
			return { row = row, col = col - 1 }
		end
		return pos
	end

	if motion == "l" then
		local len = line_len(lines, row)
		if len > 0 and col < (len - 1) then
			return { row = row, col = col + 1 }
		end
		return pos
	end

	if motion == "j" then
		if row < (#lines - 1) then
			return { row = row + 1, col = clamp_col(lines, row + 1, col) }
		end
		return pos
	end

	if motion == "k" then
		if row > 0 then
			return { row = row - 1, col = clamp_col(lines, row - 1, col) }
		end
		return pos
	end

	if motion == "w" then
		return move_w(tokens, pos)
	end

	if motion == "b" then
		return move_b(tokens, pos)
	end

	if motion == "e" then
		return move_e(tokens, pos)
	end

	return pos
end

local function key_for(pos)
	return string.format("%d:%d", pos.row, pos.col)
end

local function shortest_nav_cost(lines, start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end

	local tokens = build_tokens(lines)
	local motions = { "h", "j", "k", "l", "w", "b", "e" }
	local q = { { row = start_pos.row, col = start_pos.col } }
	local head = 1
	local dist = { [key_for(start_pos)] = 0 }

	while head <= #q do
		local cur = q[head]
		head = head + 1
		local cur_key = key_for(cur)
		local cur_dist = dist[cur_key]

		for _, motion in ipairs(motions) do
			local nxt = apply_motion(lines, tokens, cur, motion)
			if nxt.row ~= cur.row or nxt.col ~= cur.col then
				local nxt_key = key_for(nxt)
				if dist[nxt_key] == nil then
					dist[nxt_key] = cur_dist + 1
					if nxt.row == target.row and nxt.col == target.col then
						return dist[nxt_key]
					end
					q[#q + 1] = nxt
				end
			end
		end
	end

	return manhattan(start_pos, target)
end

function M._compute_nav_optimal(lines, start_pos, target)
	return shortest_nav_cost(lines, start_pos, target)
end

--- Compute the minimum (optimal) moves between two positions.
--- For small-edits, this is shortest path with lesson-supported motions:
--- h/j/k/l and word motions w/b/e.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if not current_snippet then
		return manhattan(start_pos, target)
	end
	return shortest_nav_cost(current_snippet, start_pos, target)
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char}
function M.generate_challenge(buf, ns_id)
	-- Build list of eligible indices (not recently used)
	local eligible = {}
	for i = 1, #CHALLENGES do
		local dominated = false
		for _, r in ipairs(recent) do
			if r == i then
				dominated = true
				break
			end
		end
		if not dominated then
			eligible[#eligible + 1] = i
		end
	end

	-- If all are recent, reset
	if #eligible == 0 then
		recent = {}
		for i = 1, #CHALLENGES do
			eligible[#eligible + 1] = i
		end
	end

	-- Pick random eligible challenge
	local idx = eligible[math.random(1, #eligible)]

	-- Update recency
	recent[#recent + 1] = idx
	if #recent > MAX_RECENT then
		table.remove(recent, 1)
	end

	local c = CHALLENGES[idx]
	local snippet_lines = vim.deepcopy(c.snippet_lines)
	current_snippet = snippet_lines
	return {
		snippet_lines = snippet_lines,
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		char = c.char,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
