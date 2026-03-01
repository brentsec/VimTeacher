-- vimteacher/optimal.lua
-- Shared motion-aware shortest-path utilities for lesson optimal scoring.

local M = {}

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

--- Manhattan distance helper.
--- @param start_pos table {row:number,col:number}
--- @param target table {row:number,col:number}
--- @return number
function M.manhattan(start_pos, target)
	return math.abs(start_pos.row - target.row) + math.abs(start_pos.col - target.col)
end

--- Shortest nav path cost with common motions.
--- @param lines string[]
--- @param start_pos table {row:number,col:number}
--- @param target table {row:number,col:number}
--- @param motions string[]|nil
--- @return number
function M.nav_cost(lines, start_pos, target, motions)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end
	if not lines or #lines == 0 then
		return M.manhattan(start_pos, target)
	end

	local tokens = build_tokens(lines)
	local motion_set = motions or { "h", "j", "k", "l", "w", "b", "e", "0", "^", "$" }
	local q = { { row = start_pos.row, col = start_pos.col } }
	local head = 1
	local dist = { [key_for(start_pos)] = 0 }

	while head <= #q do
		local cur = q[head]
		head = head + 1
		local cur_key = key_for(cur)
		local cur_dist = dist[cur_key]

		for _, motion in ipairs(motion_set) do
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

	return M.manhattan(start_pos, target)
end

return M
