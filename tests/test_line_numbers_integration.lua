-- tests/test_line_numbers_integration.lua
-- Integration coverage for lesson window line-number inheritance.

local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_line_numbers_integration: running...")

if vim.fn.exists(":VimTeacher") == 0 then
	vim.cmd("runtime plugin/vimteacher.lua")
end

local function runtime_state()
	return require("vimteacher.state").session
end

_G._vimteacher_test_statuscolumn = function()
	local win = (vim.g.statusline_winid and vim.g.statusline_winid ~= 0) and vim.g.statusline_winid
		or vim.api.nvim_get_current_win()
	local nu = vim.wo[win].number
	local rnu = vim.wo[win].relativenumber
	if not (nu or rnu) then
		return ""
	end
	if rnu and (not nu or vim.v.relnum ~= 0) then
		return tostring(vim.v.relnum)
	end
	return tostring(vim.v.lnum)
end

local TEST_STATUSCOLUMN = "%!v:lua._vimteacher_test_statuscolumn()"

local function configure_source_window(opts)
	vim.opt_global.number = opts.global_number
	vim.opt_global.relativenumber = opts.global_relativenumber
	vim.opt_global.statuscolumn = TEST_STATUSCOLUMN
	vim.wo[0].number = opts.local_number
	vim.wo[0].relativenumber = opts.local_relativenumber
	vim.wo[0].statuscolumn = TEST_STATUSCOLUMN
end

local function launch_vimteacher(arg)
	if arg and arg ~= "" then
		vim.cmd("VimTeacher " .. arg)
	else
		vim.cmd("VimTeacher")
	end
	return integration.wait_for(function()
		local state = runtime_state()
		return state.buf ~= nil and state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
	end, 1200)
end

local function current_line_numbers()
	return {
		number = vim.wo[0].number,
		relativenumber = vim.wo[0].relativenumber,
	}
end

local function current_statuscolumn_text()
	local state = runtime_state()
	if not state.win or not vim.api.nvim_win_is_valid(state.win) then
		return nil
	end
	local row = math.max(1, (state.snippet_offset or 0) + 1)
	local ok, result = pcall(vim.api.nvim_eval_statusline, vim.wo[state.win].statuscolumn, {
		use_statuscol_lnum = row,
		winid = state.win,
		maxwidth = 20,
	})
	if not ok then
		return nil
	end
	return vim.trim(result.str or "")
end

local function assert_line_numbers(expected, label)
	local actual = current_line_numbers()
	assert_test(
		actual.number == expected.number and actual.relativenumber == expected.relativenumber,
		label
			.. " (expected number="
			.. tostring(expected.number)
			.. ", relativenumber="
			.. tostring(expected.relativenumber)
			.. "; got number="
			.. tostring(actual.number)
			.. ", relativenumber="
			.. tostring(actual.relativenumber)
			.. ")"
	)
end

local function assert_statuscolumn(expected, label)
	local actual = current_statuscolumn_text()
	assert_test(actual == expected, label .. " (expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "')")
end

local function stop_from_current_screen()
	integration.send_key("q")
	assert_test(integration.wait_for(function()
		local state = runtime_state()
		return state.mode == "menu"
	end, 1000), "q from lesson should return to the menu")
	integration.send_key("q")
	assert_test(integration.wait_for(function()
		local state = runtime_state()
		return state.buf == nil
	end, 1000), "q from menu should stop VimTeacher")
end

local function run_menu_to_playing_case()
	configure_source_window({
		global_number = false,
		global_relativenumber = false,
		local_number = true,
		local_relativenumber = true,
	})

	assert_test(launch_vimteacher(nil), "menu start should initialize VimTeacher through the :VimTeacher command")
	assert_test(integration.wait_for(function()
		local state = runtime_state()
		return state.mode == "menu" and integration.buf_has_text("Select a Topic")
	end, 1000), "menu start should render the topic menu")
	assert_line_numbers({
		number = false,
		relativenumber = false,
	}, "menu screen should keep line numbers off")
	assert_statuscolumn("", "menu screen should not render a line-number status column")

	local row_map = vim.api.nvim_buf_get_var(0, "vimteacher_menu_row_to_lesson")
	local basic_movement_row = nil
	for row, lesson_num in pairs(row_map) do
		if lesson_num == 2 then
			basic_movement_row = row
			break
		end
	end
	assert_test(basic_movement_row ~= nil, "menu should expose a row mapping for Basic Movement")
	if not basic_movement_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { basic_movement_row, 0 })
	integration.send_key("<CR>")
	assert_test(integration.wait_for(function()
		local state = runtime_state()
		return state.mode == "playing" and integration.buf_has_text("Challenge 1/10")
	end, 1200), "pressing Enter on the highlighted lesson row should start the lesson")
	assert_line_numbers({
		number = false,
		relativenumber = true,
	}, "playing screen should inherit the source window's relative numbers only")
	assert_statuscolumn("0", "playing screen should render the visible relative-number status column")

	stop_from_current_screen()
	assert_line_numbers({
		number = true,
		relativenumber = true,
	}, "cleanup should restore the source window line-number settings")
end

local function run_local_over_global_case()
	configure_source_window({
		global_number = false,
		global_relativenumber = true,
		local_number = true,
		local_relativenumber = false,
	})

	assert_test(launch_vimteacher("basic_movement"), "direct lesson start should initialize VimTeacher through the :VimTeacher command")
	assert_test(integration.wait_for(function()
		local state = runtime_state()
		return state.mode == "playing" and integration.buf_has_text("Challenge 1/10")
	end, 1000), "direct lesson start should render the playing screen")
	assert_line_numbers({
		number = false,
		relativenumber = false,
	}, "playing screen should read the active window-local relativenumber setting, not the global default")
	assert_statuscolumn("", "playing screen should render no line-number status column when relative numbers are disabled")

	stop_from_current_screen()
	assert_line_numbers({
		number = true,
		relativenumber = false,
	}, "cleanup should restore the active window-local values after a direct lesson start")
end

local function run_info_screen_case()
	configure_source_window({
		global_number = false,
		global_relativenumber = false,
		local_number = true,
		local_relativenumber = true,
	})

	assert_test(launch_vimteacher("intro_modes"), "info lesson should initialize VimTeacher through the :VimTeacher command")
	assert_test(integration.wait_for(function()
		local state = runtime_state()
		return state.mode == "info" and integration.buf_has_text("Intro to Modes")
	end, 1000), "info lesson should render its sandbox view")
	assert_line_numbers({
		number = false,
		relativenumber = false,
	}, "info lessons should keep line numbers off because they are not challenge screens")
	assert_statuscolumn("", "info lessons should not render a line-number status column")

	stop_from_current_screen()
	assert_line_numbers({
		number = true,
		relativenumber = true,
	}, "cleanup should restore source window options after an info lesson")
end

run_menu_to_playing_case()
run_local_over_global_case()
run_info_screen_case()

counter.finish("test_line_numbers_integration")
