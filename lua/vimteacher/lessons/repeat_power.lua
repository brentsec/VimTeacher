-- vimteacher/lessons/repeat_power.lua
-- Repeat command lesson: perform a delete, then repeat it with dot.

local M = {}

M.title = "Repeat Power: . and counts"
M.type = "insert"
M.allowed_keys = {}
M.allowed_modify_keys = { "x", "." }
M.allowed_nav_keys = {
	"h",
	"j",
	"k",
	"l",
	"w",
	"b",
	"e",
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
}
M.challenges_required = 10

M.description = {
	"The dot command repeats your last change.",
	"That means you can fix one spot manually, then apply the same edit again",
	"without retyping the full command sequence each time.",
	"Each challenge is two-step:",
	"1) do the first delete on the highlighted target (x or 3x),",
	"2) move to the new target and press . to repeat it.",
}

M.hint_lines = {
	"[x] Delete char  [3x] Delete 3 chars  [.] Repeat last change",
}

local recent = {}
local MAX_RECENT = 5

--- @param line string
--- @param col number 0-indexed
--- @param n number
--- @return string
local function apply_x_n(line, col, n)
	local out = line
	for _ = 1, n do
		if col >= #out then
			break
		end
		out = out:sub(1, col) .. out:sub(col + 2)
	end
	return out
end

--- @param line string
--- @param needle string
--- @param occurrence number
--- @return number|nil 1-indexed byte position
local function find_nth(line, needle, occurrence)
	local from = 1
	local occ = occurrence or 1
	for _ = 1, occ do
		local s, e = line:find(needle, from, true)
		if not s then
			return nil
		end
		if _ == occ then
			return s
		end
		from = e + 1
	end
	return nil
end

--- @param def table
--- @return table
local function build_challenge(def)
	local snippet = vim.deepcopy(def.snippet_lines)
	local count = def.count or 1
	local key1 = (count == 1) and "x" or (tostring(count) .. "x")

	local row1 = def.phase1.row
	local line1 = snippet[row1 + 1] or ""
	local p1_start = find_nth(line1, def.phase1.find, def.phase1.occurrence or 1)
	assert(p1_start, "repeat_power phase1 find failed: " .. tostring(def.phase1.find))
	local p1_col = (p1_start - 1) + (def.phase1.offset or 0)

	local after1 = vim.deepcopy(snippet)
	after1[row1 + 1] = apply_x_n(after1[row1 + 1], p1_col, count)

	local row2 = def.phase2.row
	local line2 = after1[row2 + 1] or ""
	local p2_start = find_nth(line2, def.phase2.find, def.phase2.occurrence or 1)
	assert(p2_start, "repeat_power phase2 find failed: " .. tostring(def.phase2.find))
	local p2_col = (p2_start - 1) + (def.phase2.offset or 0)

	local after2 = vim.deepcopy(after1)
	after2[row2 + 1] = apply_x_n(after2[row2 + 1], p2_col, count)

	return {
		snippet_lines = snippet,
		expected_lines = vim.deepcopy(after2),
		target = { row = row1, col = p1_col },
		target_end_col = p1_col + count,
		start_pos = { row = def.start_pos.row, col = def.start_pos.col },
		key = key1,
		char = "x",
		phases = {
			{
				key = key1,
				char = "x",
				target = { row = row1, col = p1_col },
				target_end_col = p1_col + count,
				expected_lines = vim.deepcopy(after1),
			},
			{
				key = ".",
				char = key1,
				target = { row = row2, col = p2_col },
				target_end_col = p2_col + count,
				expected_lines = vim.deepcopy(after2),
			},
		},
	}
end

local CHALLENGE_DEFS = {
	{
		snippet_lines = {
			"function total() {",
			"  const sum = baad_value + goood_value;",
			"  return sum;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "baad_value", offset = 2 },
		phase2 = { row = 1, find = "goood_value", offset = 2 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function user() {",
			"  const first = joohn; const second = meery;",
			"  return first + second;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "joohn", offset = 2 },
		phase2 = { row = 1, find = "meery", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function path() {",
			"  const left = http:///api; const right = ws:///stream;",
			"  return left + right;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "http:///api", offset = 7 },
		phase2 = { row = 1, find = "ws:///stream", offset = 5 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function greet() {",
			'  const left = "heello"; const right = "goood";',
			"  return left + right;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "heello", offset = 2 },
		phase2 = { row = 1, find = "goood", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function calc() {",
			"  const total = 10000 + right_25000;",
			"  return total;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "10000", offset = 2 },
		phase2 = { row = 1, find = "25000", offset = 2 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function metrics() {",
			"  const cpu = 90000; const mem = 12000;",
			"  return cpu + mem;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "90000", offset = 2 },
		phase2 = { row = 1, find = "12000", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function cleanup() {",
			"  const left = value___ + right___;",
			"  return left + right;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "value___", offset = 5 },
		phase2 = { row = 1, find = "right___", offset = 5 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function flags() {",
			"  const a = truue; const b = faalse;",
			"  return a && b;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "truue", offset = 3 },
		phase2 = { row = 1, find = "faalse", offset = 2 },
		start_pos = { row = 0, col = 0 },
	},
	{
		snippet_lines = {
			"function ids() {",
			"  const one = itemm_id; const two = orderr_id;",
			"  return one + two;",
			"}",
		},
		count = 1,
		phase1 = { row = 1, find = "itemm_id", offset = 4 },
		phase2 = { row = 1, find = "orderr_id", offset = 5 },
		start_pos = { row = 3, col = 0 },
	},
	{
		snippet_lines = {
			"function labels() {",
			"  const a = alpha000; const b = beta000;",
			"  return a + b;",
			"}",
		},
		count = 3,
		phase1 = { row = 1, find = "alpha000", offset = 5 },
		phase2 = { row = 1, find = "beta000", offset = 4 },
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

local function first_non_blank(line)
	local s = line:find("%S")
	if s then
		return s - 1
	end
	return 0
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

	if motion == "0" then
		return { row = row, col = 0 }
	end

	if motion == "^" then
		return { row = row, col = first_non_blank(lines[row + 1] or "") }
	end

	if motion == "$" then
		local len = line_len(lines, row)
		if len <= 0 then
			return { row = row, col = 0 }
		end
		return { row = row, col = len - 1 }
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
	local motions = { "h", "j", "k", "l", "w", "b", "e", "0", "^", "$" }
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

--- Compute movement baseline across all phases using common Vim motions.
--- @param start_pos table {row=number, col=number}
--- @param target table {row=number, col=number}
--- @param challenge table|nil
--- @return number
function M.compute_optimal(start_pos, target, challenge)
	if challenge and challenge.phases and #challenge.phases > 0 then
		local total = 0
		local prev = { row = start_pos.row, col = start_pos.col }
		local lines = challenge.snippet_lines or {}
		for _, phase in ipairs(challenge.phases) do
			total = total + shortest_nav_cost(lines, prev, phase.target)
			if phase.expected_lines then
				lines = phase.expected_lines
			end
			prev = phase.target
		end
		return total
	end
	if challenge and challenge.snippet_lines then
		return shortest_nav_cost(challenge.snippet_lines, start_pos, target)
	end
	return manhattan(start_pos, target)
end

--- Generate challenge with recency avoidance.
--- @param _buf number
--- @param _ns_id number
--- @return table challenge
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
	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		target_end_col = c.target_end_col,
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		char = c.char,
		phases = vim.deepcopy(c.phases),
	}
end

function M._get_challenges()
	return CHALLENGES
end

return M
