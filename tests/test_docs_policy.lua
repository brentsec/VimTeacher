-- tests/test_docs_policy.lua
-- Static checks for README/help documentation alignment.

local assertions = require("helpers.assertions")
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
