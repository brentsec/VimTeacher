-- vimteacher/mode_keymaps.lua
-- Mode-specific buffer-local keymaps outside the topic menu input controller.

local lessons = require("vimteacher.lessons")

local M = {}

--- Build the keymap controller around the shared session state.
--- @param deps table
--- @return table
function M.new(deps)
	local state = deps.state
	local controller = {}

	local function clear_buf_keymaps(buf, keys)
		if not buf or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local opts = { buffer = buf }
		for _, key in ipairs(keys or {}) do
			pcall(vim.keymap.del, "n", key, opts)
		end
	end

	function controller.clear_stats_keymaps()
		clear_buf_keymaps(state.buf, { "<Space>" })
	end

	function controller.setup_playing_keymaps(show_menu_fn, start_lesson_fn)
		local buf = state.buf
		local opts = { buffer = buf, noremap = true, silent = true }
		local menu_key = state.play_menu_key or "q"
		local restart_key = state.play_restart_key or "Q"

		vim.keymap.set("n", menu_key, function()
			show_menu_fn()
		end, opts)

		vim.keymap.set("n", restart_key, function()
			start_lesson_fn(state.lesson_name)
		end, opts)
	end

	function controller.clear_playing_keymaps()
		clear_buf_keymaps(state.buf, {
			state.play_menu_key or "q",
			state.play_restart_key or "Q",
			"q",
			"Q",
			"m",
			"R",
			"gg",
			"G",
		})
	end

	function controller.setup_completion_keymaps(start_lesson_fn, show_menu_fn, cleanup_fn)
		local buf = state.buf
		local opts = { buffer = buf, noremap = true, silent = true }

		vim.keymap.set("n", "n", function()
			local next_name = lessons.get_next(state.lesson_name)
			if next_name then
				start_lesson_fn(next_name)
			else
				vim.notify("VimTeacher: No more topics available.", vim.log.levels.INFO)
			end
		end, opts)

		vim.keymap.set("n", "p", function()
			local prev_name = lessons.get_prev(state.lesson_name)
			if prev_name then
				start_lesson_fn(prev_name)
			else
				vim.notify("VimTeacher: Already at the first topic.", vim.log.levels.INFO)
			end
		end, opts)

		vim.keymap.set("n", "r", function()
			start_lesson_fn(state.lesson_name)
		end, opts)

		vim.keymap.set("n", "m", function()
			controller.clear_completion_keymaps()
			show_menu_fn()
		end, opts)

		vim.keymap.set("n", "q", function()
			cleanup_fn()
		end, opts)
	end

	function controller.clear_completion_keymaps()
		clear_buf_keymaps(state.buf, { "n", "p", "r", "m", "q" })
	end

	function controller.clear_info_keymaps()
		clear_buf_keymaps(state.buf, { "n", "<CR>", "q" })
	end

	function controller.clear_mode_keymaps(clear_menu_keymaps_fn)
		if clear_menu_keymaps_fn then
			clear_menu_keymaps_fn()
		end
		controller.clear_stats_keymaps()
		controller.clear_completion_keymaps()
		controller.clear_info_keymaps()
		controller.clear_playing_keymaps()
	end

	return controller
end

return M
