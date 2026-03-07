-- tests/test_tooling_policy.lua
-- Static checks for pinned tooling versions and repo policy.

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_tooling_policy: running...")

local function read(path)
	return table.concat(vim.fn.readfile(path), "\n")
end

local dockerfile = read("Dockerfile")
assert_test(
	dockerfile:find("ARG NEOVIM_VERSION=v0%.11%.6") ~= nil,
	"Dockerfile should pin the Neovim version used in container tests"
)
assert_test(
	dockerfile:find("/latest/download/", 1, true) == nil,
	"Dockerfile should not download the Neovim latest release"
)

local fmt_script = read("scripts/fmt")
assert_test(fmt_script:find("stylua@2%.0%.2") ~= nil, "scripts/fmt should pin the Stylua version")
assert_test(fmt_script:find("stylua@latest", 1, true) == nil, "scripts/fmt should not use stylua@latest")

local luacheckrc = read(".luacheckrc")
assert_test(
	luacheckrc:find('files%["lua/vimteacher/lessons/%*%.lua"%]') == nil,
	".luacheckrc should not suppress unused-argument warnings for every lesson file"
)

counter.finish("test_tooling_policy")
