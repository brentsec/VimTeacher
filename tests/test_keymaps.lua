-- tests/test_keymaps.lua
-- Tests for adaptive keymap resolution and Getting Started lesson rendering

local keymaps = require("vimteacher.keymaps")
local absolute_line_jumps = require("vimteacher.lessons.absolute_line_jumps")
local basic_movement = require("vimteacher.lessons.basic_movement")
local change_words = require("vimteacher.lessons.change_words")
local intro_modes = require("vimteacher.lessons.intro_modes")
local intro_operators = require("vimteacher.lessons.intro_operators")
local quick_word_search = require("vimteacher.lessons.quick_word_search")
local repeat_search = require("vimteacher.lessons.repeat_search")
local search = require("vimteacher.lessons.search")
local switch_selection_ends = require("vimteacher.lessons.switch_selection_ends")
local visual_line_mode = require("vimteacher.lessons.visual_line_mode")
local visual_mode_operators = require("vimteacher.lessons.visual_mode_operators")
local word_movement = require("vimteacher.lessons.word_movement")
local word_text_objects = require("vimteacher.lessons.word_text_objects")
local insert_mode = require("vimteacher.lessons.insert_mode")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

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

local command_pairs = {
	{ canonical = "gg", remap = "Z" },
	{ canonical = "G", remap = "X" },
	{ canonical = "dw", remap = "zg" },
	{ canonical = "d$", remap = "zx" },
	{ canonical = "u", remap = "zu" },
	{ canonical = "c", remap = "zc" },
	{ canonical = "y", remap = "zy" },
	{ canonical = "/", remap = ";" },
	{ canonical = "?", remap = "," },
	{ canonical = "n", remap = "]" },
	{ canonical = "N", remap = "[" },
	{ canonical = "*", remap = "gs" },
	{ canonical = "#", remap = "gS" },
	{ canonical = "diw", remap = "ziw" },
	{ canonical = "daw", remap = "zaw" },
	{ canonical = "ciw", remap = "xiw" },
	{ canonical = "caw", remap = "xaw" },
	{ canonical = "v", remap = "zv" },
	{ canonical = "V", remap = "zV" },
	{ canonical = "d", remap = "zd" },
	{ canonical = "o", remap = "zo" },
}
local command_cleanup_keys = {}
for _, pair in ipairs(command_pairs) do
	command_cleanup_keys[#command_cleanup_keys + 1] = pair.canonical
	command_cleanup_keys[#command_cleanup_keys + 1] = pair.remap
end
clear_maps(command_cleanup_keys)
for _, pair in ipairs(command_pairs) do
	vim.keymap.set("n", pair.canonical, "<Nop>", { noremap = true, silent = true })
	vim.keymap.set("n", pair.remap, pair.canonical, { noremap = true, silent = true })
end
keymaps.capture()
local display_commands = keymaps.resolve_many(vim.tbl_map(function(pair)
	return pair.canonical
end, command_pairs))

local absolute_title = absolute_line_jumps.get_title({ key_display = display_commands })
assert_test(
	absolute_title:find("Z, X", 1, true) ~= nil,
	"absolute_line_jumps title should render remapped gg/G keys"
)

local operators_desc = intro_operators.get_description({ key_display = display_commands })
assert_test(
	operators_desc[11]:find("zc, zy", 1, true) ~= nil and operators_desc[13]:find("zg", 1, true) ~= nil,
	"intro_operators description should render remapped operator motions"
)
local operators_hints = intro_operators.get_hint_lines({ key_display = display_commands })
assert_test(
	operators_hints[1]:find("%[zg%] Delete word") ~= nil and operators_hints[1]:find("%[zx%] Delete to end") ~= nil,
	"intro_operators hints should render remapped delete commands"
)

local change_words_title = change_words.get_title({ key_display = display_commands })
assert_test(
	change_words_title:find("cw, cW", 1, true) ~= nil,
	"change_words should preserve canonical cw/cW when unmapped"
)

local search_title = search.get_title({ key_display = display_commands })
assert_test(
	search_title:find(";, ], [", 1, true) ~= nil,
	"search title should render remapped search and repeat keys"
)
local search_hints = search.get_hint_lines({ key_display = display_commands })
assert_test(
	search_hints[1]:find("%[;word Enter%] Search") ~= nil and search_hints[1]:find("%[,word%] Backward") ~= nil,
	"search hints should render remapped forward and backward search commands"
)

local repeat_hints = repeat_search.get_hint_lines({ key_display = display_commands })
assert_test(
	repeat_hints[1]:find("%[%]%] Next match") ~= nil and repeat_hints[1]:find("%[%[%] Previous match") ~= nil,
	"repeat_search hints should render remapped n/N commands"
)

local quick_hints = quick_word_search.get_hint_lines({ key_display = display_commands })
assert_test(
	quick_hints[1]:find("%[gs%] Search word forward") ~= nil and quick_hints[1]:find("%[gS%] Search word backward") ~= nil,
	"quick_word_search hints should render remapped */# commands"
)

local word_objects_title = word_text_objects.get_title({ key_display = display_commands })
assert_test(
	word_objects_title:find("ziw, zaw, xiw, xaw", 1, true) ~= nil,
	"word_text_objects title should render remapped text objects"
)

local visual_title = visual_mode_operators.get_title({ key_display = display_commands })
assert_test(
	visual_title:find("zv + zd, zv + zc", 1, true) ~= nil,
	"visual_mode_operators title should render remapped visual/operator keys"
)

local visual_line_title = visual_line_mode.get_title({ key_display = display_commands })
assert_test(
	visual_line_title:find("zV + zd, zV + zc", 1, true) ~= nil,
	"visual_line_mode title should render remapped visual-line/operator keys"
)

local switch_title = switch_selection_ends.get_title({ key_display = display_commands })
assert_test(
	switch_title:find("zo", 1, true) ~= nil,
	"switch_selection_ends title should render remapped o key"
)

clear_maps(command_cleanup_keys)
keymaps.capture()

counter.finish("test_keymaps")
