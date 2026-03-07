-- plugin/vimteacher.lua
-- Entry point: registers :VimTeacher command
-- Auto-sourced by Neovim when the plugin is on the runtimepath

-- Version check
if vim.fn.has("nvim-0.9") == 0 then
	vim.notify("VimTeacher requires Neovim >= 0.9", vim.log.levels.ERROR)
	return
end

-- Guard against double-loading
if vim.g.loaded_vimteacher then
	return
end
vim.g.loaded_vimteacher = true

local function dev_reload_enabled()
	if vim.g.vimteacher_dev_reload == true then
		return true
	end
	local config = vim.g.vimteacher_config
	return type(config) == "table" and type(config.dev) == "table" and config.dev.reload_modules == true
end

-- Register the :VimTeacher command
vim.api.nvim_create_user_command("VimTeacher", function(opts)
	-- Clear cached modules only when development reloads are explicitly enabled.
	if dev_reload_enabled() then
		for name, _ in pairs(package.loaded) do
			if name:match("^vimteacher") then
				package.loaded[name] = nil
			end
		end
	end

	-- Launch
	vim.schedule(function()
		require("vimteacher").start(opts.args)
	end)
end, {
	nargs = "?",
	desc = "Launch VimTeacher interactive tutorial",
})
