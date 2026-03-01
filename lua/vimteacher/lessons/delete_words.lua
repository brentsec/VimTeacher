-- vimteacher/lessons/delete_words.lua
-- Lesson: Delete Words with dw and dW

local M = {}

M.title = "Delete Words: dw, dW"
M.type = "insert"
M.allowed_keys = {}
M.allowed_modify_keys = { "d" }
M.challenges_required = 10

M.description = {
	"The delete operator (d) removes text. Combine it with a motion:",
	"",
	"  dw  = delete from cursor to start of next word",
	"  dW  = delete from cursor to start of next WORD",
	"       (a WORD is everything until the next space)",
	"",
	"Tip: Deleted text is saved to your clipboard (like cut).",
	"If you start d by mistake, press Esc to cancel.",
	"",
	"Navigate to the target and delete the highlighted word.",
}

M.hint_lines = {
	"[dw] Delete word  [dW] Delete WORD  [Esc] Cancel operator",
}

-- Pre-defined challenge pool.
-- dw: deletes from cursor to next word boundary (word chars + trailing space)
-- dW: deletes from cursor to next whitespace (WORD + trailing space)
local CHALLENGES = {
	-- Challenge 1: dw — delete 'temp ' from variable name
	{
		snippet_lines = {
			"function process(data) {",
			"  const temp result = data.value;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process(data) {",
			"  const result = data.value;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 3, col = 0 },
		key = "dw",
	},

	-- Challenge 2: dw — delete 'old ' word
	{
		snippet_lines = {
			"let items = getList();",
			"let old items = getList();",
			"return items;",
		},
		expected_lines = {
			"let items = getList();",
			"let items = getList();",
			"return items;",
		},
		target = { row = 1, col = 4 },
		start_pos = { row = 0, col = 0 },
		key = "dw",
	},

	-- Challenge 3: dw — delete 'DEBUG ' from constant name
	{
		snippet_lines = {
			"const PORT = 8080;",
			"const DEBUG mode = true;",
			"const HOST = 'localhost';",
		},
		expected_lines = {
			"const PORT = 8080;",
			"const mode = true;",
			"const HOST = 'localhost';",
		},
		target = { row = 1, col = 6 },
		start_pos = { row = 2, col = 0 },
		key = "dw",
	},

	-- Challenge 4: dw — delete 'unused ' from variable
	{
		snippet_lines = {
			"function cleanup() {",
			"  const unused variable = null;",
			"  return variable;",
			"}",
		},
		expected_lines = {
			"function cleanup() {",
			"  const variable = null;",
			"  return variable;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "dw",
	},

	-- Challenge 5: dw — delete 'test ' from variable name
	{
		snippet_lines = {
			"function verify() {",
			"  let test value = compute();",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function verify() {",
			"  let value = compute();",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 6 },
		start_pos = { row = 3, col = 0 },
		key = "dw",
	},

	-- Challenge 6: dW — delete 'data.users[0].name' expression
	{
		snippet_lines = {
			"function getName() {",
			"  const result = data.users[0].name value;",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function getName() {",
			"  const result = value;",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 0, col = 0 },
		key = "dW",
	},

	-- Challenge 7: dW — delete URL from assignment
	{
		snippet_lines = {
			"const baseUrl = 'http://example.com';",
			"const apiUrl = 'http://api.example.com/v1' endpoint;",
			"return apiUrl;",
		},
		expected_lines = {
			"const baseUrl = 'http://example.com';",
			"const apiUrl = endpoint;",
			"return apiUrl;",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 2, col = 0 },
		key = "dW",
	},

	-- Challenge 8: dW — delete complex expression
	{
		snippet_lines = {
			"function calculate() {",
			"  const value = Math.floor(x/10)*100 result;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function calculate() {",
			"  const value = result;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 16 },
		start_pos = { row = 0, col = 0 },
		key = "dW",
	},

	-- Challenge 9: dw — delete 'extra ' prefix
	{
		snippet_lines = {
			"function update() {",
			"  const extra data = fetch();",
			"  return data;",
			"}",
		},
		expected_lines = {
			"function update() {",
			"  const data = fetch();",
			"  return data;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 3, col = 0 },
		key = "dw",
	},

	-- Challenge 10: dW — delete file path
	{
		snippet_lines = {
			"const configPath = './config.json';",
			"const dataPath = '../data/users.json' file;",
			"return dataPath;",
		},
		expected_lines = {
			"const configPath = './config.json';",
			"const dataPath = file;",
			"return dataPath;",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 0, col = 0 },
		key = "dW",
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5
local current_snippet = nil

--- Compute the minimum (optimal) moves between two positions.
--- Uses shortest-path over common Vim motions for realistic movement cost:
--- h/j/k/l, w/b/e, 0/^/$.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
local function manhattan(start_pos, target)
	return math.abs(start_pos.row - target.row) + math.abs(start_pos.col - target.col)
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

function M.compute_optimal(start_pos, target)
	if not current_snippet then
		return manhattan(start_pos, target)
	end
	return shortest_nav_cost(current_snippet, start_pos, target)
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key}
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
	current_snippet = c.snippet_lines
	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
