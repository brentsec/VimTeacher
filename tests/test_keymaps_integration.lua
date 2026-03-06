-- tests/test_keymaps_integration.lua
-- Runtime integration test for adaptive keymaps in lesson execution.

local vimteacher = require("vimteacher")
local basic = require("vimteacher.lessons.basic_movement")

local pass_count = 0
local fail_count = 0

local function assert_test(condition, msg)
	if condition then
		pass_count = pass_count + 1
	else
		fail_count = fail_count + 1
		print("  FAIL: " .. msg)
	end
end

local function buf_has_text(needle)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	for _, line in ipairs(lines) do
		if line:find(needle, 1, true) then
			return true
		end
	end
	return false
end

local function wait_for(predicate, timeout_ms, interval_ms)
	return vim.wait(timeout_ms or 1500, predicate, interval_ms or 20)
end

local function clear_maps(keys)
	for _, key in ipairs(keys) do
		pcall(vim.keymap.del, "n", key)
	end
end

local function send_key(key)
	local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
	vim.api.nvim_feedkeys(keys, "xt", false)
end

local function fire_cursor_moved(bufnr)
	-- Headless Neovim test runs do not emit CursorMoved from fed keys.
	-- Triggering the autocmd explicitly exercises the exact lesson callback path.
	vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr or 0 })
end

print("test_keymaps_integration: running...")

local remap_pairs = {
	{ canonical = "h", remap = "z" },
	{ canonical = "j", remap = "x" },
	{ canonical = "k", remap = "c" },
	{ canonical = "l", remap = "v" },
}

local cleanup_keys = {}
for _, pair in ipairs(remap_pairs) do
	cleanup_keys[#cleanup_keys + 1] = pair.canonical
	cleanup_keys[#cleanup_keys + 1] = pair.remap
end
clear_maps(cleanup_keys)

for _, pair in ipairs(remap_pairs) do
	vim.keymap.set("n", pair.canonical, "<Nop>", { noremap = true, silent = true })
	vim.keymap.set("n", pair.remap, pair.canonical, { noremap = true, silent = true })
end

-- Deterministic one-step challenge:
-- start at col 0 on "aaaa", target col 1 (must move right by one).
local original_generate = basic.generate_challenge
basic.generate_challenge = function()
	return {
		snippet_lines = { "aaaa" },
		target = { row = 0, col = 1 },
		start_pos = { row = 0, col = 0 },
	}
end

vimteacher.setup({
	keymaps = {
		mode = "adaptive_display",
		distro = "neovim",
	},
})
vimteacher.start("basic_movement")

assert_test(
	wait_for(function()
		return buf_has_text("Challenge 1/10")
	end, 1000),
	"Lesson should render challenge 1"
)
assert_test(buf_has_text("Move to target using z/x/c/v"), "Goal helper should render remapped movement keys")
assert_test(buf_has_text("[z] Left"), "Hint should render remapped left key")
assert_test(buf_has_text("[v] Right"), "Hint should render remapped right key")

local win = vim.api.nvim_get_current_win()
local cur0 = vim.api.nvim_win_get_cursor(win)
assert_test(cur0[2] == 0, "Initial cursor col should be 0, got " .. tostring(cur0[2]))

-- Canonical key is blocked (<Nop>): should not move and should not advance challenge.
send_key("l")
wait_for(function()
	return true
end, 60, 20)
fire_cursor_moved(0)
local cur1 = vim.api.nvim_win_get_cursor(win)
assert_test(cur1[2] == 0, "Canonical key l should be blocked and not move cursor")
assert_test(buf_has_text("Challenge 1/10"), "Challenge should remain 1/10 after blocked canonical key")

-- Remapped key should perform the movement and complete the challenge.
send_key("v")
assert_test(
	wait_for(function()
		return vim.api.nvim_win_get_cursor(win)[2] == 1
	end, 300),
	"Remapped key v should move cursor to target column"
)
fire_cursor_moved(0)
assert_test(
	wait_for(function()
		return buf_has_text("Challenge 2/10")
	end, 1500),
	"Challenge should advance to 2/10 after remapped key reaches target"
)

basic.generate_challenge = original_generate
clear_maps(cleanup_keys)

print(string.format("test_keymaps_integration: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
