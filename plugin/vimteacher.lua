-- plugin/vimteacher.lua
-- Entry point: registers :VimTeacher command
-- Auto-sourced by Neovim when the plugin is on the runtimepath

-- Version check
if vim.fn.has("nvim-0.7") == 0 then
  vim.notify("VimTeacher requires Neovim >= 0.7", vim.log.levels.ERROR)
  return
end

-- Guard against double-loading
if vim.g.loaded_vimteacher then
  return
end
vim.g.loaded_vimteacher = true

-- Register the :VimTeacher command
vim.api.nvim_create_user_command("VimTeacher", function(opts)
  -- Clear cached modules for development reloading
  for name, _ in pairs(package.loaded) do
    if name:match("^vimteacher") then
      package.loaded[name] = nil
    end
  end

  -- Launch
  require("vimteacher").start(opts.args)
end, {
  nargs = "?",
  desc = "Launch VimTeacher interactive tutorial",
})
