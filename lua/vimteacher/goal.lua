-- vimteacher/goal.lua
-- Goal bar metadata derived from lesson command keys.

local command_catalog = require("vimteacher.command_catalog")

local M = {}

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

	return {
		key = display_key or key,
		char = char,
		action = resolve_field(spec.action, key),
		preposition = resolve_field(spec.preposition, key),
	}
end

return M
