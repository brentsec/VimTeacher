-- tests/test_plugin_command.lua
-- Command registration and dev-reload behavior for plugin/vimteacher.lua.

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_plugin_command: running...")

local original_preload = package.preload["vimteacher"]
local start_arg = nil

local function cleanup()
	package.preload["vimteacher"] = original_preload
	vim.g.vimteacher_dev_reload = nil
	vim.g.vimteacher_config = nil
end

local ok, err = xpcall(function()
	package.preload["vimteacher"] = function()
		return {
			start = function(arg)
				start_arg = arg
			end,
		}
	end

	pcall(vim.api.nvim_del_user_command, "VimTeacher")
	vim.g.loaded_vimteacher = nil
	vim.g.vimteacher_dev_reload = nil
	vim.g.vimteacher_config = nil
	package.loaded["vimteacher"] = nil
	package.loaded["vimteacher.fake_module"] = nil

	vim.cmd("runtime plugin/vimteacher.lua")

	assert_test(vim.fn.exists(":VimTeacher") == 2, ":VimTeacher should be registered by the plugin entrypoint")

	package.loaded["vimteacher.fake_module"] = { sentinel = "keep" }
	vim.cmd("VimTeacher basic_movement")
	assert_test(
		vim.wait(200, function()
			return start_arg == "basic_movement"
		end, 10),
		":VimTeacher should schedule the runtime start call"
	)
	assert_test(
		package.loaded["vimteacher.fake_module"] ~= nil,
		"production :VimTeacher runs should keep cached vimteacher modules loaded"
	)

	start_arg = nil
	package.loaded["vimteacher.fake_module"] = { sentinel = "reload" }
	vim.g.vimteacher_dev_reload = true
	vim.cmd("VimTeacher intro_modes")
	assert_test(
		vim.wait(200, function()
			return start_arg == "intro_modes"
		end, 10),
		"dev reload mode should still start the requested lesson"
	)
	assert_test(
		package.loaded["vimteacher.fake_module"] == nil,
		"dev reload mode should clear cached vimteacher modules before starting"
	)
end, debug.traceback)

cleanup()

if not ok then
	error(err)
end

counter.finish("test_plugin_command")
