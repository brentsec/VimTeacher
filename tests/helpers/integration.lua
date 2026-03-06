local M = {}

function M.wait_for(predicate, timeout_ms, interval_ms)
	return vim.wait(timeout_ms or 1500, predicate, interval_ms or 20)
end

function M.clear_maps(keys)
	for _, key in ipairs(keys or {}) do
		pcall(vim.keymap.del, "n", key)
	end
end

function M.send_key(key)
	local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
	vim.api.nvim_feedkeys(keys, "mxt", false)
end

function M.fire_cursor_moved(bufnr)
	-- Headless Neovim test runs do not emit CursorMoved from fed keys.
	-- Fire the real autocmd so lesson completion still goes through production logic.
	vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr or 0 })
end

function M.current_cursor()
	return vim.api.nvim_win_get_cursor(vim.api.nvim_get_current_win())
end

function M.line_at(row_1idx)
	return vim.api.nvim_buf_get_lines(0, row_1idx - 1, row_1idx, false)[1]
end

function M.buf_has_text(needle)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	for _, line in ipairs(lines) do
		if line:find(needle, 1, true) then
			return true
		end
	end
	return false
end

function M.find_line_index(needle)
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	for idx, line in ipairs(lines) do
		if line:find(needle, 1, true) then
			return idx
		end
	end
	return nil
end

function M.perform_insert_sequence(insert_key, text)
	local insert_keys = vim.api.nvim_replace_termcodes(insert_key, true, false, true)
	vim.api.nvim_feedkeys(insert_keys, "m", false)
	M.wait_for(function()
		return true
	end, 40, 20)

	local typed = vim.api.nvim_replace_termcodes(text .. "<Esc>", true, false, true)
	vim.api.nvim_feedkeys(typed, "mtx", false)
	M.wait_for(function()
		return true
	end, 80, 20)
end

function M.prime_pending_cursor_event()
	M.fire_cursor_moved(0)
	M.wait_for(function()
		return true
	end, 60, 20)
end

function M.build_remap_index(remap_pairs)
	local cleanup_keys = {}
	local remap_for = {}

	for _, pair in ipairs(remap_pairs or {}) do
		cleanup_keys[#cleanup_keys + 1] = pair.canonical
		cleanup_keys[#cleanup_keys + 1] = pair.remap
		remap_for[pair.canonical] = pair.remap
	end

	return {
		cleanup_keys = cleanup_keys,
		remap_for = remap_for,
	}
end

function M.install_normal_remaps(remap_pairs)
	local remaps = M.build_remap_index(remap_pairs)
	M.clear_maps(remaps.cleanup_keys)

	for _, pair in ipairs(remap_pairs or {}) do
		vim.keymap.set("n", pair.canonical, "<Nop>", { noremap = true, silent = true })
		vim.keymap.set("n", pair.remap, pair.canonical, { noremap = true, silent = true })
	end

	return remaps
end

function M.configure_adaptive(vimteacher)
	vimteacher.setup({
		keymaps = {
			mode = "adaptive_display",
			distro = "neovim",
		},
	})
end

function M.with_overridden_generate(module, challenge, fn)
	local original_generate = module.generate_challenge
	module.generate_challenge = function()
		return vim.deepcopy(challenge)
	end

	local ok, result = xpcall(fn, debug.traceback)
	module.generate_challenge = original_generate

	if not ok then
		error(result)
	end

	return result
end

return M
