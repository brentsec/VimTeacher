-- vimteacher/input.lua
-- Menu input handling for the VimTeacher topic screen.

local errors = require("vimteacher.errors")

local M = {}

--- Build menu input handlers for the active session.
--- @param deps table
--- @return table
function M.new(deps)
	local menu_input_timer = nil
	local menu_input_generation = 0
	local controller = {}

	function controller.clear_menu_keymaps()
		if menu_input_timer then
			vim.fn.timer_stop(menu_input_timer)
			menu_input_timer = nil
		end
		local buf = deps.state.buf
		if not buf or not vim.api.nvim_buf_is_valid(buf) then
			return
		end
		local opts = { buffer = buf }
		for i = 0, 9 do
			pcall(vim.keymap.del, "n", tostring(i), opts)
		end
		pcall(vim.keymap.del, "n", "q", opts)
		pcall(vim.keymap.del, "n", "<CR>", opts)
	end

	function controller.setup_menu_keymaps(start_lesson, stop_session)
		local buf = deps.state.buf
		local opts = { buffer = buf, noremap = true, silent = true }
		local all_lessons = deps.lessons.get_all()
		local total = #all_lessons
		local input_buf = ""
		menu_input_generation = menu_input_generation + 1

		local function menu_input_is_active(expected_generation)
			local state = deps.state
			return menu_input_generation == expected_generation
				and state.mode == "menu"
				and state.buf == buf
				and buf
				and vim.api.nvim_buf_is_valid(buf)
		end

		local function flush_input(expected_generation)
			if not menu_input_is_active(expected_generation or menu_input_generation) then
				input_buf = ""
				return
			end
			if menu_input_timer then
				vim.fn.timer_stop(menu_input_timer)
				menu_input_timer = nil
			end
			local num = tonumber(input_buf)
			input_buf = ""
			if num and num >= 1 and num <= total then
				start_lesson(all_lessons[num].name)
			end
		end

		local function handle_digit(digit)
			if menu_input_timer then
				vim.fn.timer_stop(menu_input_timer)
				menu_input_timer = nil
			end
			input_buf = input_buf .. tostring(digit)
			local num = tonumber(input_buf)

			local could_extend = false
			if num then
				for extended = num * 10, num * 10 + 9 do
					if extended >= 1 and extended <= total then
						could_extend = true
						break
					end
				end
			end

			if not could_extend then
				flush_input(menu_input_generation)
			else
				local expected_generation = menu_input_generation
				menu_input_timer = vim.fn.timer_start(800, function()
					vim.schedule(function()
						flush_input(expected_generation)
					end)
				end)
			end
		end

		for digit = 1, 9 do
			vim.keymap.set("n", tostring(digit), function()
				handle_digit(digit)
			end, opts)
		end

		vim.keymap.set("n", "0", function()
			if input_buf ~= "" then
				handle_digit(0)
			end
		end, opts)

		vim.keymap.set("n", "q", function()
			if menu_input_timer then
				vim.fn.timer_stop(menu_input_timer)
				menu_input_timer = nil
			end
			menu_input_generation = menu_input_generation + 1
			input_buf = ""
			stop_session()
		end, opts)

		vim.keymap.set("n", "<CR>", function()
			if input_buf ~= "" then
				flush_input()
				return
			end
			local win = deps.state.win
			if not win or not vim.api.nvim_win_is_valid(win) then
				return
			end
			local row = vim.api.nvim_win_get_cursor(win)[1]
			local ok, row_map = pcall(vim.api.nvim_buf_get_var, buf, "vimteacher_menu_row_to_lesson")
			if not ok or type(row_map) ~= "table" then
				return
			end
			local lesson_num = row_map[row]
			if lesson_num and lesson_num >= 1 and lesson_num <= total then
				start_lesson(all_lessons[lesson_num].name)
			end
		end, opts)
	end

	function controller.rerender_menu_layout(render_menu)
		local state = deps.state
		if state.mode ~= "menu" then
			return
		end
		if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
			return
		end
		if not state.win or not vim.api.nvim_win_is_valid(state.win) then
			return
		end

		local cursor = vim.api.nvim_win_get_cursor(state.win)
		local ok = errors.call(
			"failed to rerender the menu layout",
			render_menu,
			state.buf,
			deps.lessons.get_sections(),
			state.all_stats,
			state.win
		)
		if not ok then
			return
		end

		local line_count = vim.api.nvim_buf_line_count(state.buf)
		local row = math.max(1, math.min(cursor[1], line_count))
		local line = vim.api.nvim_buf_get_lines(state.buf, row - 1, row, false)[1] or ""
		local col = math.max(0, math.min(cursor[2], #line))
		vim.api.nvim_win_set_cursor(state.win, { row, col })
		vim.fn.winrestview({ leftcol = 0 })
	end

	return controller
end

return M
