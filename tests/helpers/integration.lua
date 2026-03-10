local M = {}

function M.wait_for(predicate, timeout_ms, interval_ms)
	return vim.wait(timeout_ms or 1500, predicate, interval_ms or 20)
end

function M.drain(timeout_ms)
	local done = false
	vim.schedule(function()
		done = true
	end)
	return M.wait_for(function()
		return done
	end, timeout_ms or 200, 5)
end

function M.clear_maps(keys)
	for _, key in ipairs(keys or {}) do
		pcall(vim.keymap.del, "n", key)
	end
end

function M.clear_mode_maps(mode, keys)
	for _, key in ipairs(keys or {}) do
		pcall(vim.keymap.del, mode, key)
	end
end

function M.send_key(key)
	local keys = vim.api.nvim_replace_termcodes(key, true, false, true)
	vim.api.nvim_feedkeys(keys, "mxt", false)
end

function M.send_sequence(sequence, mode)
	local keys = vim.api.nvim_replace_termcodes(sequence, true, false, true)
	vim.api.nvim_feedkeys(keys, mode or "mxt", false)
end

function M.fire_cursor_moved(bufnr)
	-- Headless Neovim test runs do not emit CursorMoved from fed keys.
	-- Fire the real autocmd so lesson completion still goes through production logic.
	vim.api.nvim_exec_autocmds("CursorMoved", { buffer = bufnr or 0 })
end

function M.fire_text_changed(bufnr)
	-- Headless Neovim does not reliably emit TextChanged for fed Normal-mode edits.
	-- Fire the real autocmd so lesson completion still goes through production logic.
	vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr or 0 })
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

function M.runtime_state(vimteacher)
	local _, state = debug.getupvalue(vimteacher.start, 1)
	return state
end

function M.current_snippet_lines(vimteacher, count)
	local state = M.runtime_state(vimteacher)
	local line_count = count or ((state.snippet_end - state.snippet_offset) + 1)
	return vim.api.nvim_buf_get_lines(state.buf, state.snippet_offset, state.snippet_offset + line_count, false)
end

function M.snippet_matches(vimteacher, expected_lines)
	local actual = M.current_snippet_lines(vimteacher, #expected_lines)
	if #actual ~= #expected_lines then
		return false
	end
	for idx, expected in ipairs(expected_lines) do
		if actual[idx] ~= expected then
			return false
		end
	end
	return true
end

function M.perform_insert_sequence(insert_key, text)
	M.send_sequence(insert_key, "m")
	M.drain(80)

	M.send_sequence(text .. "<Esc>", "mtx")
	M.drain(120)
end

function M.perform_prompt_sequence(command_key, text, terminator)
	M.send_sequence(command_key, "m")
	M.drain(80)
	M.send_sequence(text .. (terminator or "<CR>"), "mtx")
	M.drain(120)
end

function M.perform_normal_with_payload(command_key, text)
	M.send_sequence(command_key .. text, "mxt")
	M.drain(120)
end

function M.move_cursor_to(row_1idx, col_0idx)
	local cur = M.current_cursor()
	local row_delta = row_1idx - cur[1]
	if row_delta > 0 then
		M.send_sequence(string.rep("j", row_delta))
	elseif row_delta < 0 then
		M.send_sequence(string.rep("k", math.abs(row_delta)))
	end

	cur = M.current_cursor()
	local col_delta = col_0idx - cur[2]
	if col_delta > 0 then
		M.send_sequence(string.rep("l", col_delta))
	elseif col_delta < 0 then
		M.send_sequence(string.rep("h", math.abs(col_delta)))
	end

	M.drain(120)
end

function M.prime_pending_cursor_event()
	M.fire_cursor_moved(0)
	M.drain(100)
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

function M.install_command_maps(remap_pairs)
	local remaps = M.build_remap_index(remap_pairs)
	M.clear_maps(remaps.cleanup_keys)

	for _, pair in ipairs(remap_pairs or {}) do
		vim.keymap.set("n", pair.canonical, "<Nop>", { noremap = true, silent = true })
		vim.keymap.set("n", pair.remap, pair.canonical, { noremap = true, silent = true })
	end

	return remaps
end

function M.install_mode_maps(mode, remap_pairs)
	local remaps = M.build_remap_index(remap_pairs)
	M.clear_mode_maps(mode, remaps.cleanup_keys)

	for _, pair in ipairs(remap_pairs or {}) do
		vim.keymap.set(mode, pair.canonical, "<Nop>", { noremap = true, silent = true })
		vim.keymap.set(mode, pair.remap, pair.canonical, { noremap = true, silent = true })
	end

	return remaps
end

function M.install_normal_remaps(remap_pairs)
	return M.install_command_maps(remap_pairs)
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
