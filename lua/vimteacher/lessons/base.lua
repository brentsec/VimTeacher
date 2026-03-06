-- vimteacher/lessons/base.lua
-- Helpers for lessons that only need adaptive text substitution.

local M = {}

local function resolve_token(tokens, name, key_display)
	local token = tokens and tokens[name]
	if token == nil then
		return name
	end
	if type(token) == "string" then
		return key_display[token] or token
	end
	if type(token) == "table" then
		local prefix = token.prefix or ""
		local suffix = token.suffix or ""
		local canonical = token.canonical or token.key or token[1]
		local fallback = token.fallback or canonical or name
		if canonical then
			local resolved = key_display[canonical] or fallback
			if prefix ~= "" or suffix ~= "" then
				return prefix .. resolved .. suffix
			end
			return resolved
		end
		return prefix .. fallback .. suffix
	end
	return tostring(token)
end

local function render_template(value, tokens, key_display)
	if type(value) == "string" then
		return (value:gsub("{{(.-)}}", function(name)
			return resolve_token(tokens, name, key_display)
		end))
	end
	if type(value) == "table" then
		local out = {}
		for idx, item in ipairs(value) do
			out[idx] = render_template(item, tokens, key_display)
		end
		return out
	end
	return value
end

--- Build a lesson table with adaptive text helpers generated from templates.
--- @param spec table
--- @return table
function M.define(spec)
	local lesson = vim.deepcopy(spec)
	local tokens = lesson.template_tokens or lesson.tokens or {}
	local title_template = lesson.title_template
	local description_template = lesson.description_template
	local hint_template = lesson.hint_template
	local sandbox_template = lesson.sandbox_template
	local goal_text_template = lesson.goal_text_template

	local function render_block(block, ctx)
		return render_template(block, tokens, (ctx and ctx.key_display) or {})
	end

	if title_template then
		lesson.title = render_block(title_template)
		lesson.get_title = function(ctx)
			return render_block(title_template, ctx)
		end
	end

	if description_template then
		lesson.description = render_block(description_template)
		lesson.get_description = function(ctx)
			return render_block(description_template, ctx)
		end
	end

	if hint_template then
		lesson.hint_lines = render_block(hint_template)
		lesson.get_hint_lines = function(ctx)
			return render_block(hint_template, ctx)
		end
	end

	if sandbox_template then
		lesson.sandbox_snippet = render_block(sandbox_template)
		lesson.get_sandbox_snippet = function(ctx)
			return render_block(sandbox_template, ctx)
		end
	end

	if goal_text_template then
		lesson.get_goal_text = function(ctx)
			return render_block(goal_text_template, ctx)
		end
	end

	lesson.title_template = nil
	lesson.description_template = nil
	lesson.hint_template = nil
	lesson.sandbox_template = nil
	lesson.goal_text_template = nil
	lesson.template_tokens = nil
	lesson.tokens = nil

	return lesson
end

return M
