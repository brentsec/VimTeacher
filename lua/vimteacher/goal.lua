-- vimteacher/goal.lua
-- Goal bar metadata derived from lesson command keys.

local M = {}

local GOAL_MATCHERS = {
	{ pattern = "^%d+x$", action = "delete", preposition = function(key)
		return key:sub(1, -2) .. " chars at cursor"
	end },
	{ pattern = "^%d+%.$", action = "repeat last change", preposition = function(key)
		return key:sub(1, -2) .. " times"
	end },
	{ pattern = "^d%d*j$", action = "delete lines", preposition = "downward" },
	{ pattern = "^d%d*k$", action = "delete lines", preposition = "upward" },
	{ pattern = "^ci", action = function(key)
		return "change inside " .. key:sub(3)
	end, preposition = "at cursor" },
	{ pattern = "^ca", action = function(key)
		return "change around " .. key:sub(3)
	end, preposition = "at cursor" },
	{ pattern = "^di", action = function(key)
		return "delete inside " .. key:sub(3)
	end, preposition = "at cursor" },
	{ pattern = "^da", action = function(key)
		return "delete around " .. key:sub(3)
	end, preposition = "at cursor" },
	{ pattern = "^V.*c$", action = "visual line change to", preposition = "selected lines" },
	{ pattern = "^V.*d$", action = "visual line delete", preposition = "selected lines" },
	{ pattern = "^v.*d$", action = "visual delete", preposition = "selected text" },
	{ pattern = "^v.*c$", action = "visual change to", preposition = "selected text" },
}

local GOAL_EXACT = {
	i = { action = "insert", preposition = "before cursor" },
	a = { action = "append", preposition = "after cursor" },
	I = { action = "insert", preposition = "at line start" },
	A = { action = "append", preposition = "at line end" },
	o = { action = "open below", preposition = "and type" },
	O = { action = "open above", preposition = "and type" },
	cl = { action = "change letter", preposition = "under cursor" },
	x = { action = "delete", preposition = "under cursor" },
	r = { action = "replace with", preposition = "under cursor" },
	["."] = { action = "repeat last change", preposition = "at cursor" },
	cw = { action = "change word to", preposition = "at cursor" },
	cW = { action = "change WORD to", preposition = "at cursor" },
	dw = { action = "delete word", preposition = "at cursor" },
	dW = { action = "delete WORD", preposition = "at cursor" },
	dd = { action = "delete", preposition = "entire line" },
	D = { action = "delete to", preposition = "end of line" },
	p = { action = "paste", preposition = "below current line" },
	P = { action = "paste", preposition = "above current line" },
	vd = { action = "visual delete", preposition = "selected text" },
	vc = { action = "visual change to", preposition = "selected text" },
}

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
--- @return table|nil
function M.build(key, char, display_key)
	if not key then
		return nil
	end

	local spec = GOAL_EXACT[key]
	if not spec then
		for _, matcher in ipairs(GOAL_MATCHERS) do
			if key:match(matcher.pattern) then
				spec = matcher
				break
			end
		end
	end
	if not spec then
		return nil
	end

	return {
		key = display_key or key,
		char = char,
		action = resolve_field(spec.action, key),
		preposition = resolve_field(spec.preposition, key),
	}
end

return M
