-- tests/minimal_init.lua
-- Minimal Neovim config for headless test execution

-- Disable all default plugins for fast startup
vim.opt.loadplugins = false

-- Detect plugin root from this test file's location
local test_dir = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h")
local plugin_root = vim.fn.fnamemodify(test_dir, ":h")

-- Add plugin to runtimepath
vim.opt.runtimepath:prepend(plugin_root)

-- Minimal settings
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
