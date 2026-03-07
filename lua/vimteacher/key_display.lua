-- vimteacher/key_display.lua
-- Adaptive key display text rewriting and lesson view construction.

local M = {}

local function escape_lua_pattern(text)
	return text:gsub("(%W)", "%%%1")
end

local function is_word_char(ch)
	return type(ch) == "string" and ch:match("[%w_]") ~= nil
end

local function is_boundary_char(ch)
	if ch == nil or ch == "" then
		return true
	end
	return ch:match("[%s%[%]%(%)%{%},:;!%?=+%-%*/\\|<>\"']") ~= nil
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
	return (
		text:gsub("()" .. escaped .. "()", function(start_pos, end_pos)
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
		end)
	)
end

local function has_count_prefix(text, start_pos)
	if start_pos <= 1 then
		return false
	end
	local idx = start_pos - 1
	if not text:sub(idx, idx):match("%d") then
		return false
	end
	while idx >= 1 and text:sub(idx, idx):match("%d") do
		idx = idx - 1
	end
	local prev = idx >= 1 and text:sub(idx, idx) or nil
	return is_boundary_char(prev)
end

local function is_prompt_prefix_char(ch)
	return type(ch) == "string" and ch ~= "" and ch:match("[%w%%\\.,%+%-]") ~= nil
end

local function replace_bounded_plain_token(text, canonical, display)
	local out = {}
	local from = 1

	while true do
		local start_pos, end_pos = text:find(canonical, from, true)
		if not start_pos then
			out[#out + 1] = text:sub(from)
			break
		end

		out[#out + 1] = text:sub(from, start_pos - 1)

		local prev = start_pos > 1 and text:sub(start_pos - 1, start_pos - 1) or nil
		local next_char = end_pos < #text and text:sub(end_pos + 1, end_pos + 1) or nil
		local replace = false

		if is_boundary_char(prev) and is_boundary_char(next_char) then
			replace = true
		elseif has_count_prefix(text, start_pos) and is_boundary_char(next_char) then
			replace = true
		elseif
			(canonical == "/" or canonical == "?" or canonical == ":")
			and is_boundary_char(prev)
			and is_prompt_prefix_char(next_char)
		then
			replace = true
		end

		out[#out + 1] = replace and display or canonical
		from = end_pos + 1
	end

	return table.concat(out)
end

--- Apply resolved key displays to a single string.
--- @param text any
--- @param key_display table|nil
--- @return any
function M.apply_to_text(text, key_display)
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
			out = replace_bounded_plain_token(out, canonical, display)
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

--- Apply resolved key displays to each string in a list.
--- @param lines any
--- @param key_display table|nil
--- @return any
function M.apply_to_lines(lines, key_display)
	if type(lines) ~= "table" then
		return lines
	end
	local out = {}
	for i, line in ipairs(lines) do
		out[i] = M.apply_to_text(line, key_display)
	end
	return out
end

--- Build a lesson view with adaptive key display substitutions applied.
--- @param lesson table
--- @param key_display table|nil
--- @return table
function M.build_lesson_view(lesson, key_display)
	local ctx = { key_display = key_display or {} }
	local view = {
		title = M.apply_to_text(lesson.title, ctx.key_display),
		description = M.apply_to_lines(lesson.description, ctx.key_display),
		hint_lines = M.apply_to_lines(lesson.hint_lines, ctx.key_display),
		goal_text = M.apply_to_text(lesson.goal_text, ctx.key_display),
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

return M
