-- tests/test_essential_motions_integration.lua
-- Runtime integration coverage for the Essential Motions section.

local vimteacher = require("vimteacher")
local upper_word_movement = require("vimteacher.lessons.upper_word_movement")
local line_ends = require("vimteacher.lessons.line_ends")
local find_char = require("vimteacher.lessons.find_char")
local till_char = require("vimteacher.lessons.till_char")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_essential_motions_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "W", remap = "z" },
	{ canonical = "E", remap = "b" },
	{ canonical = "B", remap = "n" },
	{ canonical = "0", remap = "m" },
	{ canonical = "$", remap = "y" },
	{ canonical = "_", remap = "N" },
	{ canonical = "f", remap = "l" },
	{ canonical = "F", remap = "H" },
	{ canonical = ";", remap = "M" },
	{ canonical = "t", remap = "K" },
	{ canonical = "T", remap = "L" },
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

	local snippet_row = integration.find_line_index(case.challenge.snippet_lines[1])
	assert_test(snippet_row ~= nil, case.lesson_name .. " should render deterministic snippet for " .. case.label)
	if not snippet_row then
		return nil
	end

	local cur0 = integration.current_cursor()
	local expected_start_row = snippet_row + case.challenge.start_pos.row
	assert_test(
		cur0[1] == expected_start_row and cur0[2] == case.challenge.start_pos.col,
		case.lesson_name .. " should place cursor at deterministic start for " .. case.label
	)
	integration.prime_pending_cursor_event()

	return snippet_row, cur0
end

local function assert_challenge_advanced(case)
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Challenge 2/10")
	end, 1800), case.lesson_name .. " should advance after remapped command for " .. case.label)
end

local function run_motion_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		local snippet_row, cur0 = assert_started(case)
		if not snippet_row or not cur0 then
			return
		end
		local expected_row = snippet_row + case.challenge.target.row

		integration.send_key(case.canonical)
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_cursor_moved(0)
		local blocked = integration.current_cursor()
		assert_test(
			blocked[1] == cur0[1] and blocked[2] == cur0[2],
			"canonical " .. case.canonical .. " should remain blocked for " .. case.label
		)

		integration.send_key(case.remap)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == expected_row and cur[2] == case.challenge.target.col
		end, 300), "remapped " .. case.remap .. " should move to target for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_challenge_advanced(case)
	end)
end

local function run_payload_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		local snippet_row, cur0 = assert_started(case)
		if not snippet_row or not cur0 then
			return
		end
		local expected_row = snippet_row + case.challenge.target.row

		integration.send_sequence(case.canonical .. case.arg .. "<Esc>")
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.fire_cursor_moved(0)
		local blocked = integration.current_cursor()
		assert_test(
			blocked[1] == cur0[1] and blocked[2] == cur0[2],
			"canonical " .. case.canonical .. " should remain blocked for " .. case.label
		)

		integration.perform_normal_with_payload(case.remap, case.arg)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == expected_row and cur[2] == case.challenge.target.col
		end, 300), "remapped " .. case.remap .. " should move to target for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_challenge_advanced(case)
	end)
end

local function run_repeat_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		local snippet_row, cur0 = assert_started(case)
		if not snippet_row or not cur0 then
			return
		end
		local expected_row = snippet_row + case.challenge.target.row

		integration.perform_normal_with_payload(case.primer_remap, case.primer_arg)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == cur0[1] and cur[2] == case.mid_col
		end, 300), case.lesson_name .. " should land on the first match before repeat for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_test(integration.buf_has_text("Challenge 1/10"), case.lesson_name .. " should stay on challenge 1 before repeat")

		integration.send_key(case.canonical)
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_cursor_moved(0)
		local blocked = integration.current_cursor()
		assert_test(
			blocked[1] == cur0[1] and blocked[2] == case.mid_col,
			"canonical " .. case.canonical .. " should remain blocked for " .. case.label
		)

		integration.send_key(case.repeat_remap)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == expected_row and cur[2] == case.challenge.target.col
		end, 300), "remapped repeat key " .. case.repeat_remap .. " should move to target for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_challenge_advanced(case)
	end)
end

run_motion_case({
	lesson_name = "upper_word_movement",
	module = upper_word_movement,
	label = "W moves to next WORD",
	canonical = "W",
	remap = remaps.remap_for["W"],
	expected_ui = {
		"Moving by WORDs: z, b, n",
		"[z] Next WORD",
		"[b] End of WORD",
		"[n] Back a WORD",
	},
	challenge = {
		snippet_lines = { "alpha beta/gamma delta" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 6 },
	},
})

run_motion_case({
	lesson_name = "upper_word_movement",
	module = upper_word_movement,
	label = "E moves to WORD end",
	canonical = "E",
	remap = remaps.remap_for["E"],
	expected_ui = {
		"Moving by WORDs: z, b, n",
		"[z] Next WORD",
		"[b] End of WORD",
		"[n] Back a WORD",
	},
	challenge = {
		snippet_lines = { "alpha beta/gamma delta" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 4 },
	},
})

run_motion_case({
	lesson_name = "upper_word_movement",
	module = upper_word_movement,
	label = "B moves to previous WORD",
	canonical = "B",
	remap = remaps.remap_for["B"],
	expected_ui = {
		"Moving by WORDs: z, b, n",
		"[z] Next WORD",
		"[b] End of WORD",
		"[n] Back a WORD",
	},
	challenge = {
		snippet_lines = { "alpha beta/gamma delta" },
		start_pos = { row = 0, col = 17 },
		target = { row = 0, col = 6 },
	},
})

run_motion_case({
	lesson_name = "line_ends",
	module = line_ends,
	label = "0 jumps to line start",
	canonical = "0",
	remap = remaps.remap_for["0"],
	expected_ui = {
		"Line Boundaries: m, y, N",
		"[m] Line start",
		"[y] Line end",
		"[N] First non-blank",
	},
	challenge = {
		snippet_lines = { "alpha beta" },
		start_pos = { row = 0, col = 5 },
		target = { row = 0, col = 0 },
	},
})

run_motion_case({
	lesson_name = "line_ends",
	module = line_ends,
	label = "$ jumps to line end",
	canonical = "$",
	remap = remaps.remap_for["$"],
	expected_ui = {
		"Line Boundaries: m, y, N",
		"[m] Line start",
		"[y] Line end",
		"[N] First non-blank",
	},
	challenge = {
		snippet_lines = { "alpha beta" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 9 },
	},
})

run_motion_case({
	lesson_name = "line_ends",
	module = line_ends,
	label = "_ jumps to first non-blank",
	canonical = "_",
	remap = remaps.remap_for["_"],
	expected_ui = {
		"Line Boundaries: m, y, N",
		"[m] Line start",
		"[y] Line end",
		"[N] First non-blank",
	},
	challenge = {
		snippet_lines = { "  alpha beta" },
		start_pos = { row = 0, col = 8 },
		target = { row = 0, col = 2 },
	},
})

run_payload_case({
	lesson_name = "find_char",
	module = find_char,
	label = "f finds forward to character",
	canonical = "f",
	remap = remaps.remap_for["f"],
	arg = "d",
	expected_ui = {
		"Find Character: l, H, M",
		"[l{c}] Find forward",
		"[H{c}] Find backward",
		"[M] Repeat last find",
	},
	challenge = {
		snippet_lines = { "abc def abc" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 4 },
	},
})

run_payload_case({
	lesson_name = "find_char",
	module = find_char,
	label = "F finds backward to character",
	canonical = "F",
	remap = remaps.remap_for["F"],
	arg = "d",
	expected_ui = {
		"Find Character: l, H, M",
		"[l{c}] Find forward",
		"[H{c}] Find backward",
		"[M] Repeat last find",
	},
	challenge = {
		snippet_lines = { "abc def abc" },
		start_pos = { row = 0, col = 10 },
		target = { row = 0, col = 4 },
	},
})

run_repeat_case({
	lesson_name = "find_char",
	module = find_char,
	label = "; repeats the last find",
	canonical = ";",
	repeat_remap = remaps.remap_for[";"],
	primer_remap = remaps.remap_for["f"],
	primer_arg = "x",
	expected_ui = {
		"Find Character: l, H, M",
		"[l{c}] Find forward",
		"[H{c}] Find backward",
		"[M] Repeat last find",
	},
	challenge = {
		snippet_lines = { "axbxcdx" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 3 },
	},
	mid_col = 1,
	expected_col = 3,
})

run_payload_case({
	lesson_name = "till_char",
	module = till_char,
	label = "t moves just before the character",
	canonical = "t",
	remap = remaps.remap_for["t"],
	arg = "d",
	expected_ui = {
		"Till Character: K, L, M",
		"[K{c}] Till forward",
		"[L{c}] Till backward",
		"[M] Repeat last till",
	},
	challenge = {
		snippet_lines = { "abcde" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 2 },
	},
})

run_payload_case({
	lesson_name = "till_char",
	module = till_char,
	label = "T moves just after the character",
	canonical = "T",
	remap = remaps.remap_for["T"],
	arg = "b",
	expected_ui = {
		"Till Character: K, L, M",
		"[K{c}] Till forward",
		"[L{c}] Till backward",
		"[M] Repeat last till",
	},
	challenge = {
		snippet_lines = { "abcde" },
		start_pos = { row = 0, col = 4 },
		target = { row = 0, col = 2 },
	},
})

run_repeat_case({
	lesson_name = "till_char",
	module = till_char,
	label = "; repeats the last till",
	canonical = ";",
	repeat_remap = remaps.remap_for[";"],
	primer_remap = remaps.remap_for["t"],
	primer_arg = "x",
	expected_ui = {
		"Till Character: K, L, M",
		"[K{c}] Till forward",
		"[L{c}] Till backward",
		"[M] Repeat last till",
	},
	challenge = {
		snippet_lines = { "abxcdxg" },
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 4 },
	},
	mid_col = 1,
	expected_col = 4,
})

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_essential_motions_integration")
