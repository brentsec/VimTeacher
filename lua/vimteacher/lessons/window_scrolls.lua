-- vimteacher/lessons/window_scrolls.lua
-- Lesson: Window scrolling with Ctrl+u and Ctrl+d

local M = {}

M.title = "Scrolling: Ctrl+u, Ctrl+d"
M.type = "info"

M.description = {
	"Scroll through long files without moving line by line:",
	"",
	"  Ctrl+d = scroll DOWN half a page",
	"  Ctrl+u = scroll UP half a page",
	"",
	"Hold the Ctrl key and press d or u. Your cursor moves",
	"with the scroll, staying in the middle of the screen.",
	"",
	"These work best in real files. Try them on a long file!",
	"In this small sandbox, the effect is limited.",
}

M.sandbox_snippet = {
	"-- Try Ctrl+d and Ctrl+u to scroll",
	"",
	"function fibonacci(n)",
	"  if n <= 1 then return n end",
	"  return fibonacci(n-1) + fibonacci(n-2)",
	"end",
	"",
	"function factorial(n)",
	"  if n <= 1 then return 1 end",
	"  return n * factorial(n-1)",
	"end",
	"",
	"function isPrime(n)",
	"  if n < 2 then return false end",
	"  for i = 2, math.sqrt(n) do",
	"    if n % i == 0 then return false end",
	"  end",
	"  return true",
	"end",
}

M.hint_lines = {
	"[Ctrl+d] Scroll down  [Ctrl+u] Scroll up",
	"[n] Next lesson   [q] Back to menu",
}

function M.get_title(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local down = key_display["<C-d>"] or "Ctrl+d"
	local up = key_display["<C-u>"] or "Ctrl+u"
	return string.format("Scrolling: %s, %s", up, down)
end

function M.get_description(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local down = key_display["<C-d>"] or "Ctrl+d"
	local up = key_display["<C-u>"] or "Ctrl+u"
	return {
		"Scroll through long files without moving line by line:",
		"",
		string.format("  %s = scroll DOWN half a page", down),
		string.format("  %s = scroll UP half a page", up),
		"",
		"Hold the Ctrl key and press d or u. Your cursor moves",
		"with the scroll, staying in the middle of the screen.",
		"",
		"These work best in real files. Try them on a long file!",
		"In this small sandbox, the effect is limited.",
	}
end

function M.get_hint_lines(ctx)
	local key_display = (ctx and ctx.key_display) or {}
	local down = key_display["<C-d>"] or "Ctrl+d"
	local up = key_display["<C-u>"] or "Ctrl+u"
	return {
		string.format("[%s] Scroll down  [%s] Scroll up", down, up),
		"[n] Next lesson   [q] Back to menu",
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
