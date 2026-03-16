-- vimteacher/goal.lua
-- Goal bar metadata derived from lesson command keys.

local command_catalog = require("vimteacher.command_catalog")

local M = {}

local function trim(text)
	if type(text) ~= "string" then
		return text
	end
	return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function truncate_to_width(text, width)
	if vim.api.nvim_strwidth(text) <= width then
		return text
	end

	local chars = vim.fn.strchars(text)
	for n = chars, 0, -1 do
		local candidate = vim.fn.strcharpart(text, 0, n)
		if vim.api.nvim_strwidth(candidate) <= width then
			return candidate
		end
	end

	return ""
end

local function build_open_line_reference(challenge)
	if type(challenge) ~= "table" then
		return nil
	end

	local snippet_lines = challenge.snippet_lines
	local target = challenge.target
	if type(snippet_lines) ~= "table" or type(target) ~= "table" then
		return nil
	end

	local target_line = snippet_lines[(target.row or 0) + 1]
	local trimmed = trim(target_line)
	if not trimmed or trimmed == "" then
		return nil
	end

	local const_name = trimmed:match("^(const%s+[%a_][%w_]*)")
	if const_name then
		return const_name
	end

	local return_expr = trimmed:match("^(return%s+[%a_][%w_]*)")
	if return_expr then
		return return_expr
	end

	local if_expr = trimmed:match("^(if%s*%b())")
	if if_expr then
		return if_expr
	end

	local quoted = trimmed:match("(['\"][^'\"]+['\"])")
	if quoted then
		return quoted
	end

	trimmed = trimmed:gsub("[,;]+$", "")
	return truncate_to_width(trimmed, 24)
end

local function resolve_field(field, key)
	if type(field) == "function" then
		return field(key)
	end
	return field
end

--- Build goal metadata from a challenge key/char.
--- @param key string|nil
--- @param char string|nil
--- @param display_key string|nil
--- @param challenge table|nil
--- @return table|nil
function M.build(key, char, display_key, challenge)
	if not key then
		return nil
	end

	local spec = command_catalog.goal_exact[key]
	if not spec then
		for _, matcher in ipairs(command_catalog.goal_matchers) do
			if key:match(matcher.pattern) then
				spec = matcher
				break
			end
		end
	end
	if not spec then
		return nil
	end

	local reference = nil
	if key == "o" or key == "O" then
		reference = build_open_line_reference(challenge)
	end

	return {
		key = display_key or key,
		char = trim(char),
		reference = reference,
		action = resolve_field(spec.action, key),
		preposition = resolve_field(spec.preposition, key),
	}
end

return M
