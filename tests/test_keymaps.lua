-- tests/test_keymaps.lua
-- Tests for adaptive keymap resolution and Getting Started lesson rendering

local keymaps = require("vimteacher.keymaps")
local basic_movement = require("vimteacher.lessons.basic_movement")
local intro_modes = require("vimteacher.lessons.intro_modes")
local word_movement = require("vimteacher.lessons.word_movement")
local insert_mode = require("vimteacher.lessons.insert_mode")

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

print("test_keymaps: running...")

pcall(vim.keymap.del, "n", "h")
pcall(vim.keymap.del, "n", "H")
pcall(vim.keymap.del, "n", "j")
pcall(vim.keymap.del, "n", "w")
pcall(vim.keymap.del, "n", "W")
pcall(vim.keymap.del, "n", "e")
pcall(vim.keymap.del, "n", "E")
pcall(vim.keymap.del, "n", "b")
pcall(vim.keymap.del, "n", "B")
pcall(vim.keymap.del, "n", "i")
pcall(vim.keymap.del, "n", "u")
pcall(vim.keymap.del, "n", "a")
pcall(vim.keymap.del, "n", "o")

-- h is disabled, H now performs h
vim.keymap.set("n", "h", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("n", "H", "h", { noremap = true, silent = true })
vim.keymap.set("n", "w", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("n", "W", "w", { noremap = true, silent = true })
vim.keymap.set("n", "i", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("n", "u", "i", { noremap = true, silent = true })
vim.keymap.set("n", "a", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("n", "o", "a", { noremap = true, silent = true })

keymaps.configure({
	mode = "adaptive_display",
	distro = "neovim",
	overrides = {},
})
keymaps.capture()

local display, diag = keymaps.resolve_many({ "h", "j", "k", "l", "w", "e", "b", "i", "a" })
assert_test(display["h"] == "H", "Expected h to resolve to H")
assert_test(display["j"] == "j", "Expected j to remain canonical")
assert_test(display["k"] == "k", "Expected k to remain canonical")
assert_test(display["l"] == "l", "Expected l to remain canonical")
assert_test(display["w"] == "W", "Expected w to resolve to W")
assert_test(display["e"] == "e", "Expected e to remain canonical")
assert_test(display["b"] == "b", "Expected b to remain canonical")
assert_test(display["i"] == "u", "Expected i to resolve to u")
assert_test(display["a"] == "o", "Expected a to resolve to o")

local saw_custom_h = false
for _, item in ipairs(diag.custom) do
	if item == "h->H" then
		saw_custom_h = true
		break
	end
end
assert_test(saw_custom_h, "Expected diagnostics.custom to include h->H")
local saw_custom_i = false
for _, item in ipairs(diag.custom) do
	if item == "i->u" then
		saw_custom_i = true
		break
	end
end
assert_test(saw_custom_i, "Expected diagnostics.custom to include i->u")

-- If canonical key is blocked with no viable replacement, resolver falls back to canonical and reports unresolved.
pcall(vim.keymap.del, "n", "j")
vim.keymap.set("n", "j", "<Nop>", { noremap = true, silent = true })
keymaps.capture()
local display2, diag2 = keymaps.resolve_many({ "j" })
assert_test(display2["j"] == "j", "Expected unresolved j to fallback to canonical display")
assert_test(#diag2.unresolved == 1 and diag2.unresolved[1] == "j", "Expected unresolved diagnostics for j")

local hints = basic_movement.get_hint_lines({ key_display = display })
assert_test(type(hints) == "table" and #hints >= 1, "basic_movement.get_hint_lines should return a hint line table")
assert_test(hints[1]:find("%[H%] Left") ~= nil, "Hint should render resolved key H for left movement")

local title = basic_movement.get_title({ key_display = display })
assert_test(type(title) == "string" and title:find("H, j, k, l", 1, true) ~= nil, "Title should render resolved key H")

local desc = basic_movement.get_description({ key_display = display })
assert_test(type(desc) == "table" and #desc > 0, "basic_movement.get_description should return a description table")
assert_test(desc[1]:find("H, j, k, l", 1, true) ~= nil, "Description should render resolved key H")

local goal_text = basic_movement.get_goal_text({ key_display = display })
assert_test(
	type(goal_text) == "string" and goal_text ~= "",
	"basic_movement.get_goal_text should return non-empty string"
)
assert_test(goal_text:find("H/j/k/l", 1, true) ~= nil, "Goal text should include resolved H key")

local intro_desc = intro_modes.get_description({ key_display = display })
assert_test(type(intro_desc) == "table" and #intro_desc > 0, "intro_modes.get_description should return a table")
assert_test(
	intro_desc[6]:find("H j k l", 1, true) ~= nil,
	"intro_modes description should include resolved movement keys"
)
local intro_hints = intro_modes.get_hint_lines({ key_display = display })
assert_test(type(intro_hints) == "table" and #intro_hints >= 1, "intro_modes.get_hint_lines should return hints")
assert_test(intro_hints[1]:find("%[u%] Enter insert mode") ~= nil, "intro_modes hint should render resolved insert key")
local intro_snippet = intro_modes.get_sandbox_snippet({ key_display = display })
assert_test(
	type(intro_snippet) == "table" and #intro_snippet >= 1,
	"intro_modes.get_sandbox_snippet should return snippet"
)
assert_test(
	intro_snippet[1]:find("Press u to type", 1, true) ~= nil,
	"intro_modes sandbox snippet should render resolved insert key"
)

local word_title = word_movement.get_title({ key_display = display })
assert_test(
	type(word_title) == "string" and word_title:find("W, e, b", 1, true) ~= nil,
	"word_movement title should resolve w"
)
local word_hints = word_movement.get_hint_lines({ key_display = display })
assert_test(type(word_hints) == "table" and #word_hints >= 1, "word_movement.get_hint_lines should return hints")
assert_test(word_hints[1]:find("%[W%] Next word") ~= nil, "word_movement hint should render resolved W key")
local word_goal = word_movement.get_goal_text({ key_display = display })
assert_test(
	type(word_goal) == "string" and word_goal:find("W/e/b", 1, true) ~= nil,
	"word_movement goal should resolve w"
)

local insert_title = insert_mode.get_title({ key_display = display })
assert_test(
	type(insert_title) == "string" and insert_title:find("u, o", 1, true) ~= nil,
	"insert_mode title should resolve i/a"
)
local insert_desc = insert_mode.get_description({ key_display = display })
assert_test(type(insert_desc) == "table" and #insert_desc > 0, "insert_mode.get_description should return table")
assert_test(insert_desc[3]:find("u = insert before cursor", 1, true) ~= nil, "insert_mode description should resolve i")
assert_test(insert_desc[3]:find("o = append after cursor", 1, true) ~= nil, "insert_mode description should resolve a")
local insert_hints = insert_mode.get_hint_lines({ key_display = display })
assert_test(type(insert_hints) == "table" and #insert_hints >= 1, "insert_mode.get_hint_lines should return hints")
assert_test(insert_hints[1]:find("%[u%] Insert before cursor") ~= nil, "insert_mode hint should resolve i")
assert_test(insert_hints[1]:find("%[o%] Append after cursor") ~= nil, "insert_mode hint should resolve a")

pcall(vim.keymap.del, "n", "h")
pcall(vim.keymap.del, "n", "H")
pcall(vim.keymap.del, "n", "j")
pcall(vim.keymap.del, "n", "w")
pcall(vim.keymap.del, "n", "W")
pcall(vim.keymap.del, "n", "i")
pcall(vim.keymap.del, "n", "u")
pcall(vim.keymap.del, "n", "a")
pcall(vim.keymap.del, "n", "o")

print(string.format("test_keymaps: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
