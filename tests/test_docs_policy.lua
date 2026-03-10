-- tests/test_docs_policy.lua
-- Static checks for README/help documentation alignment.

local assertions = require("helpers.assertions")
local lessons = require("vimteacher.lessons")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_docs_policy: running...")

local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

local readme = read("README.md")
assert_test(readme:find("Neovim >= 0%.9") ~= nil, "README should document the minimum Neovim version as 0.9")
assert_test(
	readme:find('"brentsec/VimTeacher"', 1, true) ~= nil,
	"README should show the standard remote lazy.nvim plugin spec"
)
assert_test(
	readme:find('dir = "/path/to/apps/vim%-teacher"') ~= nil,
	"README should keep the local lazy.nvim development example"
)
assert_test(
	readme:find("`gameplay.lua`'s `on_cursor_moved()` handler", 1, true) ~= nil,
	"README should point dwell validation at gameplay.lua's on_cursor_moved() handler"
)
assert_test(
	readme:find("`M.sections`", 1, true) ~= nil,
	"README should document that new lessons are registered in M.sections"
)

local visible_lessons = 0
for _, section in ipairs(lessons.get_sections()) do
	visible_lessons = visible_lessons + #section.lessons
	assert_test(
		readme:find("### " .. section.title, 1, true) ~= nil,
		"README should document the visible lesson section '" .. section.title .. "'"
	)
	for _, lesson in ipairs(section.lessons) do
		assert_test(
			readme:find(lesson.title, 1, true) ~= nil,
			"README should list the visible lesson '" .. lesson.title .. "'"
		)
	end
end
assert_test(
	readme:find("## Available Topics (" .. visible_lessons .. " lessons)", 1, true) ~= nil,
	"README should report the visible lesson count from the registry"
)

local plugin_entry = read("plugin/vimteacher.lua")
assert_test(
	plugin_entry:find('has%("nvim%-0%.9"%)') ~= nil,
	"plugin entrypoint should enforce the same minimum Neovim version documented in the README"
)

local vimdoc = read("doc/vimteacher.txt")
assert_test(vimdoc:find("%*vimteacher%.txt%*") ~= nil, "vimdoc should ship a help file banner")
assert_test(vimdoc:find("%*:VimTeacher%*") ~= nil, "vimdoc should document the :VimTeacher command")
assert_test(vimdoc:find("%*vimteacher%-config%*") ~= nil, "vimdoc should expose a configuration section")

local helptags = read("doc/tags")
assert_test(helptags:find("vimteacher%.txt", 1, false) ~= nil, "doc/tags should include VimTeacher help tags")

counter.finish("test_docs_policy")
