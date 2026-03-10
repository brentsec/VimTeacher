-- tests/test_line_numbers_integration.lua
-- Integration coverage for lesson window line-number inheritance.

local assertions = require("helpers.assertions")
local integration = require("helpers.integration")
local buffer = require("vimteacher.buffer")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_line_numbers_integration: running...")

if vim.fn.exists(":VimTeacher") == 0 then
	vim.cmd("runtime plugin/vimteacher.lua")
end

local function runtime_state()
	return require("vimteacher.state").session
end

local original = {
	test_statuscolumn = _G._vimteacher_test_statuscolumn,
	go_number = vim.go.number,
	go_relativenumber = vim.go.relativenumber,
	go_statuscolumn = vim.go.statuscolumn,
	global_number = vim.opt_global.number:get(),
	global_relativenumber = vim.opt_global.relativenumber:get(),
	global_statuscolumn = vim.opt_global.statuscolumn:get(),
	window_number = vim.wo[0].number,
	window_relativenumber = vim.wo[0].relativenumber,
	window_statuscolumn = vim.wo[0].statuscolumn,
	buffer_filetype = vim.bo[0].filetype,
	buffer_buftype = vim.bo[0].buftype,
}
local created_augroups = {}

local function cleanup()
	local state_mod = require("vimteacher.state")
	local state = state_mod.session

	if state.mode ~= "menu" and state.buf ~= nil then
		pcall(vim.cmd, "VimTeacherStop")
	end

	if state.buf ~= nil and vim.api.nvim_buf_is_valid(state.buf) then
		pcall(vim.api.nvim_buf_delete, state.buf, { force = true })
	end

	for _, augroup in ipairs(created_augroups) do
		pcall(vim.api.nvim_del_augroup_by_id, augroup)
	end

	_G._vimteacher_test_statuscolumn = original.test_statuscolumn
	vim.go.number = original.go_number
	vim.go.relativenumber = original.go_relativenumber
	vim.go.statuscolumn = original.go_statuscolumn
	vim.opt_global.number = original.global_number
	vim.opt_global.relativenumber = original.global_relativenumber
	vim.opt_global.statuscolumn = original.global_statuscolumn
	vim.wo[0].number = original.window_number
	vim.wo[0].relativenumber = original.window_relativenumber
	vim.wo[0].statuscolumn = original.window_statuscolumn
	vim.bo[0].filetype = original.buffer_filetype
	vim.bo[0].buftype = original.buffer_buftype

	state_mod.reset()
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
	vim.go.number = opts.global_number
	vim.go.relativenumber = opts.global_relativenumber
	vim.go.statuscolumn = TEST_STATUSCOLUMN
	vim.opt_global.number = opts.global_number
	vim.opt_global.relativenumber = opts.global_relativenumber
	vim.opt_global.statuscolumn = TEST_STATUSCOLUMN
	vim.wo[0].number = opts.local_number
	vim.wo[0].relativenumber = opts.local_relativenumber
	vim.wo[0].statuscolumn = TEST_STATUSCOLUMN
	if opts.filetype ~= nil then
		vim.bo[0].filetype = opts.filetype
	end
	if opts.buftype ~= nil then
		vim.bo[0].buftype = opts.buftype
	end
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
	local snapshot = buffer.inspect_line_numbers(state.win, math.max(1, (state.snippet_offset or 0) + 1))
	return snapshot and snapshot.rendered or nil
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
	assert_test(
		actual == expected,
		label .. " (expected '" .. tostring(expected) .. "', got '" .. tostring(actual) .. "')"
	)
end

local function assert_statuscolumn_visible(label)
	local actual = current_statuscolumn_text()
	assert_test(
		actual ~= nil and actual ~= "",
		label .. " (expected visible gutter text, got '" .. tostring(actual) .. "')"
	)
end

local function assert_live_window_matches_state(label)
	local state = runtime_state()
	local current_win = vim.api.nvim_get_current_win()
	local current_buf = vim.api.nvim_get_current_buf()
	assert_test(current_win == state.win, label .. " should keep the lesson buffer in the active window")
	assert_test(current_buf == state.buf, label .. " should keep the lesson buffer in the active buffer")
end

local function assert_playing_gutter_persists(label)
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			local snapshot = buffer.inspect_line_numbers(state.win, math.max(1, (state.snippet_offset or 0) + 1))
			return snapshot
				and snapshot.relativenumber == true
				and snapshot.statuscolumn:find("lesson_statuscolumn", 1, true) ~= nil
				and snapshot.rendered ~= nil
				and snapshot.rendered ~= ""
		end, 300, 25),
		label .. " should keep the custom lesson statuscolumn after startup settles"
	)
end

local function stop_from_current_screen()
	integration.send_key("q")
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "menu"
		end, 1000),
		"q from lesson should return to the menu"
	)
	integration.send_key("q")
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.buf == nil
		end, 1000),
		"q from menu should stop VimTeacher"
	)
end

local function run_menu_to_playing_case()
	configure_source_window({
		global_number = false,
		global_relativenumber = false,
		local_number = true,
		local_relativenumber = true,
	})

	assert_test(launch_vimteacher(nil), "menu start should initialize VimTeacher through the :VimTeacher command")
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "menu" and integration.buf_has_text("Select a Topic")
		end, 1000),
		"menu start should render the topic menu"
	)
	assert_line_numbers({
		number = false,
		relativenumber = false,
	}, "menu screen should keep line numbers off")
	assert_statuscolumn("", "menu screen should not render a line-number status column")

	local row_map = vim.api.nvim_buf_get_var(0, "vimteacher_menu_row_to_lesson")
	local row_to_col = vim.api.nvim_buf_get_var(0, "vimteacher_menu_row_to_col")
	local intro_row = nil
	local basic_movement_row = nil
	for row, lesson_num in pairs(row_map) do
		if lesson_num == 1 then
			intro_row = row
		end
		if lesson_num == 2 then
			basic_movement_row = row
		end
	end
	assert_test(intro_row ~= nil, "menu should expose a row mapping for Intro to Modes")
	assert_test(basic_movement_row ~= nil, "menu should expose a row mapping for Basic Movement")
	local intro_col = intro_row and row_to_col[intro_row] or nil
	assert_test(type(intro_col) == "number", "menu should expose a cursor column for the first lesson row")
	local menu_cursor = vim.api.nvim_win_get_cursor(0)
	assert_test(
		intro_row ~= nil and intro_col ~= nil and menu_cursor[1] == intro_row and menu_cursor[2] == intro_col,
		"menu should place the cursor on the first lesson number when VimTeacher opens"
	)
	if not intro_row or not basic_movement_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { basic_movement_row, 0 })
	integration.send_key("<CR>")
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "playing" and integration.buf_has_text("Challenge 1/10")
		end, 1200),
		"pressing Enter on the highlighted lesson row should start the lesson"
	)
	assert_live_window_matches_state("playing screen from menu")
	assert_line_numbers({
		number = true,
		relativenumber = true,
	}, "playing screen should inherit the source window's visible line-number settings")
	assert_statuscolumn_visible("playing screen should render the visible relative-number status column")
	assert_playing_gutter_persists("playing screen from menu")

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

	assert_test(
		launch_vimteacher("basic_movement"),
		"direct lesson start should initialize VimTeacher through the :VimTeacher command"
	)
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "playing" and integration.buf_has_text("Challenge 1/10")
		end, 1000),
		"direct lesson start should render the playing screen"
	)
	assert_live_window_matches_state("direct lesson start")
	assert_line_numbers({
		number = true,
		relativenumber = false,
	}, "playing screen should read the active window-local number settings, not the global defaults")
	assert_statuscolumn_visible(
		"playing screen should render the absolute line-number gutter when the source window keeps number enabled"
	)
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			local snapshot = buffer.inspect_line_numbers(state.win, math.max(1, (state.snippet_offset or 0) + 1))
			return snapshot
				and snapshot.number == true
				and snapshot.relativenumber == false
				and snapshot.statuscolumn:find("lesson_statuscolumn", 1, true) ~= nil
				and snapshot.rendered ~= nil
				and snapshot.rendered ~= ""
		end, 300, 25),
		"playing screen should keep the absolute-number gutter when the source window disables relative numbers"
	)

	stop_from_current_screen()
	assert_line_numbers({
		number = true,
		relativenumber = false,
	}, "cleanup should restore the active window-local values after a direct lesson start")
end

local function run_window_move_case()
	configure_source_window({
		global_number = false,
		global_relativenumber = false,
		local_number = true,
		local_relativenumber = true,
	})

	assert_test(
		launch_vimteacher("basic_movement"),
		"window move case should initialize VimTeacher through the :VimTeacher command"
	)
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "playing" and integration.buf_has_text("Challenge 1/10")
		end, 1000),
		"window move case should render the playing screen"
	)

	local state = runtime_state()
	local original_win = state.win
	local lesson_buf = state.buf

	vim.cmd("vsplit")
	local moved_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(moved_win, lesson_buf)

	local replacement_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(original_win, replacement_buf)
	vim.api.nvim_set_current_win(moved_win)

	integration.fire_cursor_moved(lesson_buf)
	assert_test(
		integration.wait_for(function()
			local refreshed = runtime_state()
			return refreshed.win == moved_win and vim.api.nvim_win_is_valid(refreshed.win)
		end, 400, 20),
		"cursor handling should refresh state.win after the lesson buffer moves to another window"
	)
	assert_live_window_matches_state("moved lesson window")
	assert_line_numbers({
		number = true,
		relativenumber = true,
	}, "moved lesson window should keep playing line-number settings")
	assert_statuscolumn_visible("moved lesson window should still render the playing gutter")

	stop_from_current_screen()
	if vim.api.nvim_win_is_valid(moved_win) and #vim.api.nvim_list_wins() > 1 then
		vim.api.nvim_set_current_win(original_win)
		pcall(vim.api.nvim_win_close, moved_win, true)
	end
end

local function run_info_screen_case()
	configure_source_window({
		global_number = false,
		global_relativenumber = false,
		local_number = true,
		local_relativenumber = true,
	})

	assert_test(
		launch_vimteacher("intro_modes"),
		"info lesson should initialize VimTeacher through the :VimTeacher command"
	)
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "info" and integration.buf_has_text("Intro to Modes")
		end, 1000),
		"info lesson should render its sandbox view"
	)
	assert_live_window_matches_state("info lesson")
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

local function run_dashboard_fallback_case(filetype)
	local augroup = vim.api.nvim_create_augroup("VimTeacherDashboardLineNumberTest", { clear = true })
	created_augroups[#created_augroups + 1] = augroup
	vim.api.nvim_create_autocmd("BufEnter", {
		group = augroup,
		callback = function(args)
			if vim.bo[args.buf].buftype == "" then
				vim.wo.number = true
				vim.wo.relativenumber = true
			end
		end,
	})
	vim.api.nvim_create_autocmd("FileType", {
		group = augroup,
		pattern = filetype,
		callback = function()
			vim.wo.number = false
			vim.wo.relativenumber = false
		end,
	})

	configure_source_window({
		global_number = true,
		global_relativenumber = true,
		local_number = true,
		local_relativenumber = true,
		filetype = filetype,
		buftype = "nofile",
	})

	assert_test(
		launch_vimteacher("small_edits"),
		filetype .. " start should initialize VimTeacher through the :VimTeacher command"
	)
	assert_test(
		integration.wait_for(function()
			local state = runtime_state()
			return state.mode == "playing" and integration.buf_has_text("Challenge 1/10")
		end, 1000),
		filetype .. " start should render the playing screen"
	)
	assert_live_window_matches_state(filetype .. " lesson start")
	assert_line_numbers({
		number = true,
		relativenumber = true,
	}, "playing screen should fall back to global editing defaults when started from a UI buffer (" .. filetype .. ")")
	assert_statuscolumn_visible(filetype .. " start should render the line-number gutter from global defaults")

	stop_from_current_screen()
	assert_test(
		vim.api.nvim_get_current_win() ~= nil,
		"cleanup should leave a valid active window after a UI-buffer-launched lesson (" .. filetype .. ")"
	)
end

local ok, err = xpcall(function()
	run_menu_to_playing_case()
	run_local_over_global_case()
	run_window_move_case()
	run_info_screen_case()
	run_dashboard_fallback_case("snacks_dashboard")
	run_dashboard_fallback_case("nvdash")
end, debug.traceback)

cleanup()

if not ok then
	error(err)
end

counter.finish("test_line_numbers_integration")
