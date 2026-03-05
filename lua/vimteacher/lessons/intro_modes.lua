-- vimteacher/lessons/intro_modes.lua
-- First lesson: Introduction to Vim modes (normal vs insert)

local M = {}

M.title = "Intro to Modes"
M.type = "info"
M.adaptive_keys = { "h", "j", "k", "l", "i" }

M.description = {
	"Vim has two main modes:",
	"",
	"  Normal mode — keys are COMMANDS (move cursor, not type text)",
	"  Insert mode — keys TYPE TEXT (like a regular editor)",
	"",
	"Right now you are in Normal mode. Try moving with h j k l.",
	"",
	"Press i to enter Insert mode — now you can type!",
	"Press Esc to return to Normal mode.",
	"",
	"Practice switching modes in the sandbox below.",
}

M.sandbox_snippet = {
	"-- Try it! Press i to type, Esc to go back",
	"",
	"function hello()",
	'  print("hello world")',
	"end",
}

M.hint_lines = {
	"[i] Enter insert mode    [Esc] Back to normal mode",
	"[n] Next lesson      [q] Back to menu",
}

--- Build intro description with resolved keys.
--- @param ctx table|nil { key_display = { [canonical]=display } }
--- @return string[]
function M.get_description(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local h = key_display["h"] or "h"
	local j = key_display["j"] or "j"
	local k = key_display["k"] or "k"
	local l = key_display["l"] or "l"
	local i_key = key_display["i"] or "i"
	return {
		"Vim has two main modes:",
		"",
		"  Normal mode — keys are COMMANDS (move cursor, not type text)",
		"  Insert mode — keys TYPE TEXT (like a regular editor)",
		"",
		string.format("Right now you are in Normal mode. Try moving with %s %s %s %s.", h, j, k, l),
		"",
		string.format("Press %s to enter Insert mode — now you can type!", i_key),
		"Press Esc to return to Normal mode.",
		"",
		"Practice switching modes in the sandbox below.",
	}
end

--- Build intro hints with resolved insert key.
--- @param ctx table|nil { key_display = { [canonical]=display } }
--- @return string[]
function M.get_hint_lines(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local i_key = key_display["i"] or "i"
	return {
		string.format("[%s] Enter insert mode    [Esc] Back to normal mode", i_key),
		"[n] Next lesson      [q] Back to menu",
	}
end

--- Build sandbox snippet with resolved insert key.
--- @param ctx table|nil { key_display = { [canonical]=display } }
--- @return string[]
function M.get_sandbox_snippet(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local i_key = key_display["i"] or "i"
	return {
		string.format("-- Try it! Press %s to type, Esc to go back", i_key),
		"",
		"function hello()",
		'  print("hello world")',
		"end",
	}
end

--- Generate a challenge (no-op for info lessons, satisfies registry validation).
--- @return table challenge
function M.generate_challenge()
	return {
		snippet_lines = vim.deepcopy(M.sandbox_snippet),
	}
end

return M
