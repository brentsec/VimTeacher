-- vimteacher/lessons/window_scrolls.lua
-- Lesson: Window scrolling with Ctrl+u and Ctrl+d

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Scrolling: {{scroll_up}}, {{scroll_down}}",
	type = "info",
	description_template = {
		"Scroll through long files without moving line by line:",
		"",
		"  {{scroll_down}} = scroll DOWN half a page",
		"  {{scroll_up}} = scroll UP half a page",
		"",
		"Hold the Ctrl key and press d or u. Your cursor moves",
		"with the scroll, staying in the middle of the screen.",
		"",
		"These work best in real files. Try them on a long file!",
		"In this small sandbox, the effect is limited.",
	},
	sandbox_template = {
		"-- Try {{scroll_down}} and {{scroll_up}} to scroll",
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
	},
	hint_template = {
		"[{{scroll_down}}] Scroll down  [{{scroll_up}}] Scroll up",
		"[n] Next lesson   [q] Back to menu",
	},
	template_tokens = {
		scroll_up = { canonical = "<C-u>", fallback = "Ctrl+u" },
		scroll_down = { canonical = "<C-d>", fallback = "Ctrl+d" },
	},
})
--- Generate a challenge (no-op for info lessons, satisfies registry validation).
--- @return table challenge
function M.generate_challenge()
	return {
		snippet_lines = vim.deepcopy(M.sandbox_snippet),
	}
end

return M
