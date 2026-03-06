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

local canonical_keys = { "h", "j", "k", "l", "w", "e", "b", "i", "a" }
local remap_pairs = {
	{ canonical = "h", remap = "z" },
	{ canonical = "j", remap = "x" },
	{ canonical = "k", remap = "c" },
	{ canonical = "l", remap = "v" },
	{ canonical = "w", remap = "g" },
	{ canonical = "e", remap = "y" },
	{ canonical = "b", remap = "n" },
	{ canonical = "i", remap = "u" },
	{ canonical = "a", remap = "p" },
}

local function clear_maps(keys)
	for _, key in ipairs(keys) do
		pcall(vim.keymap.del, "n", key)
	end
end

local cleanup_keys = {}
for _, pair in ipairs(remap_pairs) do
	cleanup_keys[#cleanup_keys + 1] = pair.canonical
	cleanup_keys[#cleanup_keys + 1] = pair.remap
end
clear_maps(cleanup_keys)

-- Adaptive test: all canonical keys are blocked and remapped to non-default keys.
for _, pair in ipairs(remap_pairs) do
	vim.keymap.set("n", pair.canonical, "<Nop>", { noremap = true, silent = true })
	vim.keymap.set("n", pair.remap, pair.canonical, { noremap = true, silent = true })
end

keymaps.configure({
	mode = "adaptive_display",
	distro = "neovim",
	overrides = {},
})
keymaps.capture()

local display, diag = keymaps.resolve_many(canonical_keys)
for _, pair in ipairs(remap_pairs) do
	assert_test(
		display[pair.canonical] == pair.remap,
		string.format("Expected %s to resolve to %s", pair.canonical, pair.remap)
	)
	local needle = pair.canonical .. "->" .. pair.remap
	local found = false
	for _, item in ipairs(diag.custom) do
		if item == needle then
			found = true
			break
		end
	end
	assert_test(found, "Expected diagnostics.custom to include " .. needle)
end

-- If canonical key is blocked with no viable replacement, resolver falls back to canonical and reports unresolved.
pcall(vim.keymap.del, "n", "x")
vim.keymap.set("n", "j", "<Nop>", { noremap = true, silent = true })
keymaps.capture()
local display2, diag2 = keymaps.resolve_many({ "j" })
assert_test(display2["j"] == "j", "Expected unresolved j to fallback to canonical display")
assert_test(#diag2.unresolved == 1 and diag2.unresolved[1] == "j", "Expected unresolved diagnostics for j")

local hints = basic_movement.get_hint_lines({ key_display = display })
assert_test(type(hints) == "table" and #hints >= 1, "basic_movement.get_hint_lines should return a hint line table")
assert_test(hints[1]:find("%[z%] Left") ~= nil, "Hint should render resolved key z for left movement")

local title = basic_movement.get_title({ key_display = display })
assert_test(
	type(title) == "string" and title:find("z, x, c, v", 1, true) ~= nil,
	"Title should render resolved movement keys"
)

local desc = basic_movement.get_description({ key_display = display })
assert_test(type(desc) == "table" and #desc > 0, "basic_movement.get_description should return a description table")
assert_test(desc[1]:find("z, x, c, v", 1, true) ~= nil, "Description should render resolved movement keys")

local goal_text = basic_movement.get_goal_text({ key_display = display })
assert_test(
	type(goal_text) == "string" and goal_text ~= "",
	"basic_movement.get_goal_text should return non-empty string"
)
assert_test(goal_text:find("z/x/c/v", 1, true) ~= nil, "Goal text should include resolved movement keys")

local intro_desc = intro_modes.get_description({ key_display = display })
assert_test(type(intro_desc) == "table" and #intro_desc > 0, "intro_modes.get_description should return a table")
assert_test(
	intro_desc[6]:find("z x c v", 1, true) ~= nil,
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
	type(word_title) == "string" and word_title:find("g, y, n", 1, true) ~= nil,
	"word_movement title should resolve w"
)
local word_hints = word_movement.get_hint_lines({ key_display = display })
assert_test(type(word_hints) == "table" and #word_hints >= 1, "word_movement.get_hint_lines should return hints")
assert_test(word_hints[1]:find("%[g%] Next word") ~= nil, "word_movement hint should render resolved g key")
local word_goal = word_movement.get_goal_text({ key_display = display })
assert_test(
	type(word_goal) == "string" and word_goal:find("g/y/n", 1, true) ~= nil,
	"word_movement goal should resolve w"
)

local insert_title = insert_mode.get_title({ key_display = display })
assert_test(
	type(insert_title) == "string" and insert_title:find("u, p", 1, true) ~= nil,
	"insert_mode title should resolve i/a"
)
local insert_desc = insert_mode.get_description({ key_display = display })
assert_test(type(insert_desc) == "table" and #insert_desc > 0, "insert_mode.get_description should return table")
assert_test(insert_desc[3]:find("u = insert before cursor", 1, true) ~= nil, "insert_mode description should resolve i")
assert_test(insert_desc[3]:find("p = append after cursor", 1, true) ~= nil, "insert_mode description should resolve a")
local insert_hints = insert_mode.get_hint_lines({ key_display = display })
assert_test(type(insert_hints) == "table" and #insert_hints >= 1, "insert_mode.get_hint_lines should return hints")
assert_test(insert_hints[1]:find("%[u%] Insert before cursor") ~= nil, "insert_mode hint should resolve i")
assert_test(insert_hints[1]:find("%[p%] Append after cursor") ~= nil, "insert_mode hint should resolve a")

-- Case-sensitive reverse mappings must not collapse lowercase and uppercase commands.
clear_maps({ "o", "O", "m", "M" })
vim.keymap.set("n", "o", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("n", "O", "<Nop>", { noremap = true, silent = true })
vim.keymap.set("n", "m", "o", { noremap = true, silent = true })
vim.keymap.set("n", "M", "O", { noremap = true, silent = true })
keymaps.capture()
local open_display, open_diag = keymaps.resolve_many({ "o", "O" })
assert_test(open_display["o"] == "m", "Expected lowercase o to resolve to lowercase m")
assert_test(open_display["O"] == "M", "Expected uppercase O to resolve to uppercase M")
assert_test(
	vim.tbl_contains(open_diag.custom, "o->m"),
	"Expected diagnostics.custom to include lowercase o remap"
)
assert_test(
	vim.tbl_contains(open_diag.custom, "O->M"),
	"Expected diagnostics.custom to include uppercase O remap"
)

-- Default baseline test: no custom mappings means canonical display keys.
clear_maps(cleanup_keys)
clear_maps({ "o", "O", "m", "M" })
keymaps.capture()
local display_default, diag_default = keymaps.resolve_many(canonical_keys)
for _, key in ipairs(canonical_keys) do
	assert_test(display_default[key] == key, "Expected default key display for " .. key)
end
assert_test(#diag_default.custom == 0, "Expected no custom diagnostics with default keymaps")
assert_test(#diag_default.unresolved == 0, "Expected no unresolved diagnostics with default keymaps")

local default_basic_title = basic_movement.get_title({ key_display = display_default })
assert_test(default_basic_title:find("h, j, k, l", 1, true) ~= nil, "Default basic_movement title should be canonical")
local default_intro_hints = intro_modes.get_hint_lines({ key_display = display_default })
assert_test(
	default_intro_hints[1]:find("%[i%] Enter insert mode") ~= nil,
	"Default intro_modes hint should be canonical"
)
local default_word_title = word_movement.get_title({ key_display = display_default })
assert_test(default_word_title:find("w, e, b", 1, true) ~= nil, "Default word_movement title should be canonical")
local default_insert_title = insert_mode.get_title({ key_display = display_default })
assert_test(default_insert_title:find("i, a", 1, true) ~= nil, "Default insert_mode title should be canonical")

print(string.format("test_keymaps: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
