-- vimteacher/highlight_plan.lua
-- Computes semantic highlight regions for challenge targets.

local M = {}

-- Commands where the target should always be the anchor character itself.
local SINGLE_CHAR_ANCHOR_KEYS = {
	i = true,
	a = true,
	I = true,
	A = true,
	x = true,
	r = true,
	cl = true,
	["."] = true,
}

-- Commands where the line anchor matters more than a single character.
local FULL_LINE_ANCHOR_KEYS = {
	dd = true,
	o = true,
	O = true,
	p = true,
	P = true,
}

--- Compute highlight range from vim motion semantics.
--- @param key string Vim key/motion (e.g., "dw", "cW", "di(")
--- @param snippet_line string Snippet line text
--- @param target_col number 0-indexed target column
--- @return number|nil end_col 0-indexed exclusive end column (nil for line-level ops)
--- @return boolean full_line Whether to highlight the entire line
--- @return number|nil start_col_override 0-indexed start column override
function M.compute_motion_end(key, snippet_line, target_col)
	if key == "dd" then
		return nil, true
	end
	if key == "D" then
		return #snippet_line, false
	end

	-- Text objects: [operator][ia][object]
	local to_prefix = key:sub(1, 2)
	local to_char = key:sub(3)
	local is_inside = (to_prefix == "di" or to_prefix == "ci")
	local is_around = (to_prefix == "da" or to_prefix == "ca")

	if is_inside or is_around then
		-- Bracket pairs
		local bracket_map = {
			["("] = { "(", ")" },
			[")"] = { "(", ")" },
			["["] = { "[", "]" },
			["]"] = { "[", "]" },
			["{"] = { "{", "}" },
			["}"] = { "{", "}" },
		}
		local pair = bracket_map[to_char]
		if pair then
			local open_ch, close_ch = pair[1], pair[2]
			local open_pos
			for i = target_col, 0, -1 do
				if snippet_line:sub(i + 1, i + 1) == open_ch then
					open_pos = i
					break
				end
			end
			local close_pos
			for i = target_col, #snippet_line - 1 do
				if snippet_line:sub(i + 1, i + 1) == close_ch then
					close_pos = i
					break
				end
			end
			if open_pos and close_pos and close_pos > open_pos then
				if is_inside then
					-- Empty inside pair: highlight delimiters to show insertion context.
					if close_pos == open_pos + 1 then
						return close_pos + 1, false, open_pos
					end
					return close_pos, false, open_pos + 1
				end
				return close_pos + 1, false, open_pos
			end
		end

		-- Quote pairs
		if to_char == '"' or to_char == "'" then
			local q = to_char
			local open_pos
			for i = target_col, 0, -1 do
				if snippet_line:sub(i + 1, i + 1) == q then
					open_pos = i
					break
				end
			end
			local close_pos
			if open_pos then
				for i = open_pos + 1, #snippet_line - 1 do
					if snippet_line:sub(i + 1, i + 1) == q then
						close_pos = i
						break
					end
				end
			end
			if open_pos and close_pos and close_pos > open_pos then
				if is_inside then
					if close_pos == open_pos + 1 then
						return close_pos + 1, false, open_pos
					end
					return close_pos, false, open_pos + 1
				end
				return close_pos + 1, false, open_pos
			end
		end

		-- Word text objects (diw, daw, ciw, caw)
		if to_char == "w" then
			local function char_at(idx)
				return snippet_line:sub(idx + 1, idx + 1)
			end

			local ws = target_col
			while ws > 0 and char_at(ws - 1):match("[%w_]") do
				ws = ws - 1
			end

			local we = target_col
			while we < #snippet_line - 1 and char_at(we + 1):match("[%w_]") do
				we = we + 1
			end

			if is_inside then
				return we + 1, false, ws
			end

			local trail = we + 1
			while trail < #snippet_line and char_at(trail):match("%s") do
				trail = trail + 1
			end
			if trail > we + 1 then
				return trail, false, ws
			end

			local lead = ws
			while lead > 0 and char_at(lead - 1):match("%s") do
				lead = lead - 1
			end
			return we + 1, false, lead
		end
	end

	local rest = snippet_line:sub(target_col + 1)
	if #rest == 0 then
		return target_col + 1, false
	end

	local first = rest:sub(1, 1)
	if key == "dw" or key == "cw" then
		local word_len
		if first:match("[%w_]") then
			word_len = #(rest:match("^[%w_]+") or "")
		elseif first:match("%s") then
			word_len = #(rest:match("^%s+") or "")
		else
			word_len = #(rest:match("^[^%w%s_]+") or "")
		end
		if key == "dw" then
			local trailing = (rest:sub(word_len + 1)):match("^(%s+)") or ""
			return target_col + word_len + #trailing, false
		end
		return target_col + word_len, false
	end

	if key == "dW" or key == "cW" then
		local word_len
		if first:match("%s") then
			word_len = #(rest:match("^%s+") or "")
		else
			word_len = #(rest:match("^%S+") or "")
		end
		if key == "dW" then
			local trailing = (rest:sub(word_len + 1)):match("^(%s+)") or ""
			return target_col + word_len + #trailing, false
		end
		return target_col + word_len, false
	end

	return nil, false
end

--- Compute semantic highlight plan for a challenge.
--- @param challenge table Challenge data
--- @return table|nil plan {start_col, end_col, full_line}
function M.compute_for_challenge(challenge)
	if not challenge or not challenge.target then
		return nil
	end

	local target = challenge.target
	local key = challenge.key
	local line = challenge.snippet_lines and challenge.snippet_lines[target.row + 1]
	local plan = {
		start_col = target.col,
		end_col = challenge.target_end_col,
		full_line = false,
	}

	if key and FULL_LINE_ANCHOR_KEYS[key] then
		plan.start_col = 0
		plan.end_col = nil
		plan.full_line = true
		return plan
	end

	if key and (SINGLE_CHAR_ANCHOR_KEYS[key] or key:match("^%d+%.$")) then
		plan.start_col = target.col
		plan.end_col = target.col + 1
		return plan
	end

	-- Visual character operations: highlight selected span directly.
	if key and key:match("^v.*[dc]$") and challenge.select_end and challenge.select_end.row == target.row then
		local start_col = math.min(target.col, challenge.select_end.col)
		local end_col = math.max(target.col, challenge.select_end.col) + 1
		plan.start_col = start_col
		plan.end_col = end_col
		return plan
	end

	if key and line then
		local end_col, full_line, start_col_override = M.compute_motion_end(key, line, target.col)
		if full_line then
			plan.start_col = 0
			plan.end_col = nil
			plan.full_line = true
			return plan
		end
		plan.end_col = end_col or plan.end_col
		if start_col_override ~= nil then
			plan.start_col = start_col_override
		end
	end

	-- Fallback: backward-scan for keys not handled by motion semantics.
	if not plan.end_col and challenge.expected_lines and line then
		local e_line = challenge.expected_lines[target.row + 1]
		if e_line then
			local si, ei = #line, #e_line
			while si > target.col and ei > 0 and line:byte(si) == e_line:byte(ei) do
				si = si - 1
				ei = ei - 1
			end
			plan.end_col = si
		end
	end

	return plan
end

return M
