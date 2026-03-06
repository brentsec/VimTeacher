-- tests/test_advanced_vertical_movement_integration.lua
-- Runtime integration coverage for the Advanced Vertical Movement section.

local vimteacher = require("vimteacher")
local relative_line_jumps = require("vimteacher.lessons.relative_line_jumps")
local absolute_line_jumps = require("vimteacher.lessons.absolute_line_jumps")
local paragraph_jumps = require("vimteacher.lessons.paragraph_jumps")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_advanced_vertical_movement_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "j", remap = "m" },
	{ canonical = "k", remap = "n" },
	{ canonical = "gg", remap = "zz" },
	{ canonical = "G", remap = "Z" },
	{ canonical = "}", remap = "]" },
	{ canonical = "{", remap = "[" },
	{ canonical = "<C-d>", remap = "L" },
	{ canonical = "<C-u>", remap = "H" },
})

integration.configure_adaptive(vimteacher)

local function assert_started(case)
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Challenge 1/10")
	end, 1000), case.lesson_name .. " should render challenge 1 for " .. case.label)
	for _, expected_ui in ipairs(case.expected_ui or {}) do
		assert_test(
			integration.buf_has_text(expected_ui),
			case.lesson_name .. " should render adaptive text '" .. expected_ui .. "' for " .. case.label
		)
	end
	assert_test(integration.snippet_matches(vimteacher, case.challenge.snippet_lines), case.lesson_name .. " should render deterministic snippet for " .. case.label)
	integration.prime_pending_cursor_event()
end

local function run_movement_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)

		integration.send_sequence(case.canonical)
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.fire_cursor_moved(0)
		local blocked = integration.current_cursor()
		assert_test(
			blocked[1] == case.challenge.start_pos.row + integration.find_line_index(case.challenge.snippet_lines[1])
				and blocked[2] == case.challenge.start_pos.col,
			"canonical " .. case.canonical .. " should remain blocked for " .. case.label
		)

		integration.send_sequence(case.remap)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			local snippet_row = integration.find_line_index(case.challenge.snippet_lines[1])
			return cur[1] == (snippet_row + case.challenge.target.row) and cur[2] == case.challenge.target.col
		end, 400), "remapped command should move to target for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped command for " .. case.label)
	end)
end

local function run_info_scroll_case()
	vimteacher.start("window_scrolls")
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Scrolling: H, L")
	end, 1000), "window_scrolls should render adaptive title")
	assert_test(integration.buf_has_text("[L] Scroll down"), "window_scrolls should render remapped scroll-down hint")
	assert_test(integration.buf_has_text("[H] Scroll up"), "window_scrolls should render remapped scroll-up hint")

	vim.api.nvim_win_set_height(0, 8)
	local sandbox_row = integration.find_line_index("function factorial(n)")
	assert_test(sandbox_row ~= nil, "window_scrolls should render its sandbox snippet")
	if not sandbox_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { sandbox_row, 0 })
	local view0 = vim.fn.winsaveview()

	integration.send_sequence("<C-d>")
	integration.wait_for(function()
		return true
	end, 80, 20)
	local view_after_blocked_down = vim.fn.winsaveview()
	assert_test(view_after_blocked_down.topline == view0.topline, "canonical <C-d> should remain blocked in window_scrolls")

	integration.send_sequence("L")
	assert_test(integration.wait_for(function()
		return vim.fn.winsaveview().topline > view0.topline
	end, 300), "remapped scroll-down key should move the window view")

	local view1 = vim.fn.winsaveview()
	integration.send_sequence("<C-u>")
	integration.wait_for(function()
		return true
	end, 80, 20)
	local view_after_blocked_up = vim.fn.winsaveview()
	assert_test(view_after_blocked_up.topline == view1.topline, "canonical <C-u> should remain blocked in window_scrolls")

	integration.send_sequence("H")
	assert_test(integration.wait_for(function()
		return vim.fn.winsaveview().topline < view1.topline
	end, 300), "remapped scroll-up key should move the window view back")
end

run_movement_case({
	lesson_name = "relative_line_jumps",
	module = relative_line_jumps,
	label = "count+j uses the remapped down key",
	canonical = "5j",
	remap = "5" .. remaps.remap_for["j"],
	expected_ui = {
		"Line Jumps: 5m, 3n",
		"[count+m] Jump down",
		"[count+n] Jump up",
	},
	challenge = {
		snippet_lines = {
			"line 1",
			"line 2",
			"line 3",
			"line 4",
			"line 5",
			"line 6",
			"line 7",
			"line 8",
		},
		start_pos = { row = 0, col = 0 },
		target = { row = 5, col = 0 },
	},
})

run_movement_case({
	lesson_name = "relative_line_jumps",
	module = relative_line_jumps,
	label = "count+k uses the remapped up key",
	canonical = "3k",
	remap = "3" .. remaps.remap_for["k"],
	expected_ui = {
		"Line Jumps: 5m, 3n",
		"[count+m] Jump down",
		"[count+n] Jump up",
	},
	challenge = {
		snippet_lines = {
			"line 1",
			"line 2",
			"line 3",
			"line 4",
			"line 5",
			"line 6",
			"line 7",
			"line 8",
		},
		start_pos = { row = 5, col = 0 },
		target = { row = 2, col = 0 },
	},
})

run_movement_case({
	lesson_name = "absolute_line_jumps",
	module = absolute_line_jumps,
	label = "gg uses the remapped jump-to-top sequence",
	canonical = "gg",
	remap = remaps.remap_for["gg"],
	expected_ui = {
		"Jump to Top/Bottom: zz, Z",
		"[zz] Jump to top",
		"[Z] Jump to bottom",
	},
	challenge = {
		snippet_lines = {
			"top line",
			"middle line",
			"bottom line",
		},
		start_pos = { row = 2, col = 0 },
		target = { row = 0, col = 0 },
		row_only_check = true,
		highlight_rows = { 0 },
	},
})

run_movement_case({
	lesson_name = "absolute_line_jumps",
	module = absolute_line_jumps,
	label = "G uses the remapped jump-to-bottom key",
	canonical = "G",
	remap = remaps.remap_for["G"],
	expected_ui = {
		"Jump to Top/Bottom: zz, Z",
		"[zz] Jump to top",
		"[Z] Jump to bottom",
	},
	challenge = {
		snippet_lines = {
			"top line",
			"middle line",
			"bottom line",
		},
		start_pos = { row = 0, col = 0 },
		target = { row = 2, col = 0 },
		row_only_check = true,
		highlight_rows = { 2 },
	},
})

run_movement_case({
	lesson_name = "paragraph_jumps",
	module = paragraph_jumps,
	label = "} uses the remapped next-paragraph key",
	canonical = "}",
	remap = remaps.remap_for["}"],
	expected_ui = {
		"Paragraph Jumps: ], [",
		"] Next paragraph",
		"Previous paragraph",
	},
	challenge = {
		snippet_lines = {
			"alpha",
			"beta",
			"",
			"gamma",
			"delta",
			"",
			"epsilon",
		},
		start_pos = { row = 0, col = 0 },
		target = { row = 2, col = 0 },
		highlight_rows = { 2 },
	},
})

run_movement_case({
	lesson_name = "paragraph_jumps",
	module = paragraph_jumps,
	label = "{ uses the remapped previous-paragraph key",
	canonical = "{",
	remap = remaps.remap_for["{"],
	expected_ui = {
		"Paragraph Jumps: ], [",
		"] Next paragraph",
		"Previous paragraph",
	},
	challenge = {
		snippet_lines = {
			"alpha",
			"beta",
			"",
			"gamma",
			"delta",
			"",
			"epsilon",
		},
		start_pos = { row = 6, col = 0 },
		target = { row = 5, col = 0 },
		highlight_rows = { 5 },
	},
})

run_info_scroll_case()

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_advanced_vertical_movement_integration")
