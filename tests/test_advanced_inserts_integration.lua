-- tests/test_advanced_inserts_integration.lua
-- Runtime integration coverage for the Advanced Inserts section.

local vimteacher = require("vimteacher")
local line_inserts = require("vimteacher.lessons.line_inserts")
local open_lines = require("vimteacher.lessons.open_lines")
local small_edits = require("vimteacher.lessons.small_edits")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_advanced_inserts_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "I", remap = "u" },
	{ canonical = "A", remap = "p" },
	{ canonical = "o", remap = "m" },
	{ canonical = "O", remap = "M" },
	{ canonical = "x", remap = "b" },
	{ canonical = "r", remap = "n" },
	{ canonical = "cl", remap = "fg" },
})

integration.configure_adaptive(vimteacher)

local function run_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
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
			return
		end

		local cur0 = integration.current_cursor()
		local expected_start_row = snippet_row + case.challenge.start_pos.row
		assert_test(
			cur0[1] == expected_start_row and cur0[2] == case.challenge.start_pos.col,
			case.lesson_name .. " should place cursor at deterministic start for " .. case.label
		)

		local target_row = snippet_row + case.challenge.target.row
		local original_line = integration.line_at(target_row)
		integration.send_sequence(case.challenge.key)
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(
			integration.line_at(target_row) == original_line,
			"canonical " .. case.challenge.key .. " should remain blocked for " .. case.label
		)

		if case.exec == "insert" then
			integration.perform_insert_sequence(case.remap, case.challenge.char)
		elseif case.exec == "normal_payload" then
			integration.perform_normal_with_payload(case.remap, case.challenge.char)
			integration.fire_text_changed(0)
		else
			integration.send_sequence(case.remap)
			integration.wait_for(function()
				return true
			end, 80, 20)
			integration.fire_text_changed(0)
		end

		assert_test(integration.wait_for(function()
			return integration.buf_has_text(case.expected_text)
		end, 400), case.lesson_name .. " should apply expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1500), case.lesson_name .. " should advance after remapped command for " .. case.label)
	end)
end

run_case({
	lesson_name = "line_inserts",
	module = line_inserts,
	label = "I inserts at first non-blank",
	remap = remaps.remap_for["I"],
	exec = "insert",
	expected_text = "  foo",
	expected_ui = {
		"Line Inserts: u, p",
		"[u] Insert at line start  [p] Append at line end",
	},
	challenge = {
		snippet_lines = { "  oo" },
		expected_lines = { "  foo" },
		target = { row = 0, col = 2 },
		start_pos = { row = 0, col = 2 },
		key = "I",
		char = "f",
	},
})

run_case({
	lesson_name = "line_inserts",
	module = line_inserts,
	label = "A appends at line end",
	remap = remaps.remap_for["A"],
	exec = "insert",
	expected_text = "hi;",
	expected_ui = {
		"Line Inserts: u, p",
		"[u] Insert at line start  [p] Append at line end",
	},
	challenge = {
		snippet_lines = { "hi" },
		expected_lines = { "hi;" },
		target = { row = 0, col = 1 },
		start_pos = { row = 0, col = 0 },
		key = "A",
		char = ";",
	},
})

run_case({
	lesson_name = "open_lines",
	module = open_lines,
	label = "o opens below",
	remap = remaps.remap_for["o"],
	exec = "insert",
	expected_text = "  work();",
	expected_ui = {
		"Open New Lines: m, M",
		"[m] Open below  [M] Open above",
	},
	challenge = {
		snippet_lines = {
			"if (ok) {",
			"}",
		},
		expected_lines = {
			"if (ok) {",
			"  work();",
			"}",
		},
		target = { row = 0, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "o",
		char = "  work();",
	},
})

run_case({
	lesson_name = "open_lines",
	module = open_lines,
	label = "O opens above",
	remap = remaps.remap_for["O"],
	exec = "insert",
	expected_text = "const total = 1;",
	expected_ui = {
		"Open New Lines: m, M",
		"[m] Open below  [M] Open above",
	},
	challenge = {
		snippet_lines = {
			"return total;",
		},
		expected_lines = {
			"const total = 1;",
			"return total;",
		},
		target = { row = 0, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "O",
		char = "const total = 1;",
	},
})

run_case({
	lesson_name = "small_edits",
	module = small_edits,
	label = "x deletes one character",
	remap = remaps.remap_for["x"],
	exec = "normal",
	expected_text = "bad",
	expected_ui = {
		"Small Edits: fg, b, n",
		"[b] Delete char  [n] Replace char  [fg] Change letter",
	},
	challenge = {
		snippet_lines = { "baad" },
		expected_lines = { "bad" },
		target = { row = 0, col = 2 },
		start_pos = { row = 0, col = 2 },
		key = "x",
	},
})

run_case({
	lesson_name = "small_edits",
	module = small_edits,
	label = "r replaces one character",
	remap = remaps.remap_for["r"],
	exec = "normal_payload",
	expected_text = "bot",
	expected_ui = {
		"Small Edits: fg, b, n",
		"[b] Delete char  [n] Replace char  [fg] Change letter",
	},
	challenge = {
		snippet_lines = { "bat" },
		expected_lines = { "bot" },
		target = { row = 0, col = 1 },
		start_pos = { row = 0, col = 1 },
		key = "r",
		char = "o",
	},
})

run_case({
	lesson_name = "small_edits",
	module = small_edits,
	label = "cl changes one character and enters insert",
	remap = remaps.remap_for["cl"],
	exec = "insert",
	expected_text = "const",
	expected_ui = {
		"Small Edits: fg, b, n",
		"[b] Delete char  [n] Replace char  [fg] Change letter",
	},
	challenge = {
		snippet_lines = { "cot" },
		expected_lines = { "const" },
		target = { row = 0, col = 1 },
		start_pos = { row = 0, col = 1 },
		key = "cl",
		char = "ons",
	},
})

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_advanced_inserts_integration")
