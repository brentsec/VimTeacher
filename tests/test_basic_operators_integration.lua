-- tests/test_basic_operators_integration.lua
-- Runtime integration coverage for the Basic Operators section.

local vimteacher = require("vimteacher")
local delete_words = require("vimteacher.lessons.delete_words")
local change_words = require("vimteacher.lessons.change_words")
local delete_lines = require("vimteacher.lessons.delete_lines")
local delete_multiple_lines = require("vimteacher.lessons.delete_multiple_lines")
local copy_paste_lines = require("vimteacher.lessons.copy_paste_lines")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_basic_operators_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "dw", remap = "zg" },
	{ canonical = "dW", remap = "zG" },
	{ canonical = "cw", remap = "hg" },
	{ canonical = "cW", remap = "hG" },
	{ canonical = "dd", remap = "zz" },
	{ canonical = "D", remap = "Z" },
	{ canonical = "dj", remap = "zj" },
	{ canonical = "dk", remap = "zk" },
	{ canonical = "d2j", remap = "z2j" },
	{ canonical = "d2k", remap = "z2k" },
	{ canonical = "yy", remap = "mm" },
	{ canonical = "p", remap = "b" },
	{ canonical = "P", remap = "B" },
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
	assert_test(integration.snippet_matches(vimteacher, case.challenge.snippet_lines), case.lesson_name .. " should render the deterministic snippet for " .. case.label)
end

local function run_delete_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)

		integration.send_sequence(case.challenge.key)
		integration.wait_for(function()
			return true
		end, 80, 20)
		assert_test(
			integration.snippet_matches(vimteacher, case.challenge.snippet_lines),
			"canonical " .. case.challenge.key .. " should remain blocked for " .. case.label
		)

		integration.send_sequence(case.remap)
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 400), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped command for " .. case.label)
	end)
end

local function run_change_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)

		integration.send_sequence(case.challenge.key)
		integration.wait_for(function()
			return true
		end, 80, 20)
		assert_test(
			integration.snippet_matches(vimteacher, case.challenge.snippet_lines),
			"canonical " .. case.challenge.key .. " should remain blocked for " .. case.label
		)

		integration.perform_insert_sequence(case.remap, case.challenge.char)
		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 500), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped command for " .. case.label)
	end)
end

local function run_copy_paste_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)

		vim.fn.setreg('"', "")
		integration.send_sequence(case.challenge.yank_key or "yy")
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.send_sequence(case.challenge.key)
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.fire_text_changed(0)
		assert_test(
			integration.snippet_matches(vimteacher, case.challenge.snippet_lines),
			"canonical yank/paste should remain blocked for " .. case.label
		)

		vim.fn.setreg('"', "")
		integration.send_sequence(case.yank_remap)
		integration.wait_for(function()
			return vim.fn.getreg('"') ~= ""
		end, 200)
		integration.send_sequence(case.paste_remap)
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 500), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped command for " .. case.label)
	end)
end

local function run_intro_case()
	vimteacher.start("intro_operators")
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Intro to Operators")
	end, 1000), "intro_operators should render its title")
	assert_test(integration.buf_has_text("[zg] Delete word"), "intro_operators should render remapped delete-word hint")

	local sandbox_row = integration.find_line_index('const greeting = "hello world";')
	assert_test(sandbox_row ~= nil, "intro_operators should render the sandbox snippet")
	if not sandbox_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { sandbox_row, 6 })
	local original_line = integration.line_at(sandbox_row)

	integration.send_sequence("dw")
	integration.wait_for(function()
		return true
	end, 80, 20)
	assert_test(integration.line_at(sandbox_row) == original_line, "canonical dw should remain blocked in intro_operators")

	integration.send_sequence(remaps.remap_for["dw"])
	assert_test(integration.wait_for(function()
		return integration.line_at(sandbox_row) == 'const = "hello world";'
	end, 300), "remapped delete-word command should edit the intro_operators sandbox")
end

run_intro_case()

run_delete_case({
	lesson_name = "delete_words",
	module = delete_words,
	label = "dw deletes a word with remapped sequence",
	remap = remaps.remap_for["dw"],
	expected_ui = {
		"Delete Words: zg, zG",
		"[zg] Delete word",
		"[zG] Delete WORD",
	},
	challenge = {
		snippet_lines = { "const temp result = value;" },
		expected_lines = { "const result = value;" },
		target = { row = 0, col = 6 },
		start_pos = { row = 0, col = 6 },
		key = "dw",
	},
})

run_delete_case({
	lesson_name = "delete_words",
	module = delete_words,
	label = "dW deletes a WORD with remapped sequence",
	remap = remaps.remap_for["dW"],
	expected_ui = {
		"Delete Words: zg, zG",
		"[zg] Delete word",
		"[zG] Delete WORD",
	},
	challenge = {
		snippet_lines = { "const value = path/to/file result;" },
		expected_lines = { "const value = result;" },
		target = { row = 0, col = 14 },
		start_pos = { row = 0, col = 14 },
		key = "dW",
	},
})

run_change_case({
	lesson_name = "change_words",
	module = change_words,
	label = "cw changes a word with remapped sequence",
	remap = remaps.remap_for["cw"],
	expected_ui = {
		"Change Words: hg, hG",
		"[hg] Change word",
		"[hG] Change WORD",
	},
	challenge = {
		snippet_lines = { "const temp = value;" },
		expected_lines = { "const result = value;" },
		target = { row = 0, col = 6 },
		start_pos = { row = 0, col = 6 },
		key = "cw",
		char = "result",
	},
})

run_change_case({
	lesson_name = "change_words",
	module = change_words,
	label = "cW changes a WORD with remapped sequence",
	remap = remaps.remap_for["cW"],
	expected_ui = {
		"Change Words: hg, hG",
		"[hg] Change word",
		"[hG] Change WORD",
	},
	challenge = {
		snippet_lines = { "const url = http://localhost:3000 next;" },
		expected_lines = { "const url = https://api.example.com next;" },
		target = { row = 0, col = 12 },
		start_pos = { row = 0, col = 12 },
		key = "cW",
		char = "https://api.example.com",
	},
})

run_delete_case({
	lesson_name = "delete_lines",
	module = delete_lines,
	label = "dd deletes the full line with remapped sequence",
	remap = remaps.remap_for["dd"],
	expected_ui = {
		"Delete Lines: zz, Z",
		"[zz] Delete line",
		"[Z] Delete to end of line",
	},
	challenge = {
		snippet_lines = {
			"const keep = true;",
			"const drop = false;",
			"return keep;",
		},
		expected_lines = {
			"const keep = true;",
			"return keep;",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 1, col = 0 },
		key = "dd",
	},
})

run_delete_case({
	lesson_name = "delete_lines",
	module = delete_lines,
	label = "D deletes to end of line with remapped key",
	remap = remaps.remap_for["D"],
	expected_ui = {
		"Delete Lines: zz, Z",
		"[zz] Delete line",
		"[Z] Delete to end of line",
	},
	challenge = {
		snippet_lines = {
			'const host = "localhost"; // remove this',
		},
		expected_lines = {
			'const host = "localhost";',
		},
		target = { row = 0, col = 25 },
		start_pos = { row = 0, col = 25 },
		key = "D",
	},
})

run_delete_case({
	lesson_name = "delete_multiple_lines",
	module = delete_multiple_lines,
	label = "dj deletes the target line and the one below",
	remap = remaps.remap_for["dj"],
	expected_ui = {
		"Multi-Line Delete: zj, zk",
		"[zj] Delete 2 lines down",
		"[zk] Delete 2 lines up",
	},
	challenge = {
		snippet_lines = {
			"keep one",
			"drop two",
			"drop three",
			"keep four",
		},
		expected_lines = {
			"keep one",
			"keep four",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 1, col = 0 },
		key = "dj",
	},
})

run_delete_case({
	lesson_name = "delete_multiple_lines",
	module = delete_multiple_lines,
	label = "dk deletes the target line and the one above",
	remap = remaps.remap_for["dk"],
	expected_ui = {
		"Multi-Line Delete: zj, zk",
		"[zj] Delete 2 lines down",
		"[zk] Delete 2 lines up",
	},
	challenge = {
		snippet_lines = {
			"keep one",
			"drop two",
			"drop three",
			"keep four",
		},
		expected_lines = {
			"keep one",
			"keep four",
		},
		target = { row = 2, col = 0 },
		start_pos = { row = 2, col = 0 },
		key = "dk",
	},
})

run_delete_case({
	lesson_name = "delete_multiple_lines",
	module = delete_multiple_lines,
	label = "d2j deletes three lines downward",
	remap = remaps.remap_for["d2j"],
	expected_ui = {
		"[z2j] Delete 3 down",
		"[z2k] Delete 3 up",
	},
	challenge = {
		snippet_lines = {
			"keep one",
			"drop two",
			"drop three",
			"drop four",
			"keep five",
		},
		expected_lines = {
			"keep one",
			"keep five",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 1, col = 0 },
		key = "d2j",
	},
})

run_delete_case({
	lesson_name = "delete_multiple_lines",
	module = delete_multiple_lines,
	label = "d2k deletes three lines upward",
	remap = remaps.remap_for["d2k"],
	expected_ui = {
		"[z2j] Delete 3 down",
		"[z2k] Delete 3 up",
	},
	challenge = {
		snippet_lines = {
			"keep one",
			"drop two",
			"drop three",
			"drop four",
			"keep five",
		},
		expected_lines = {
			"keep one",
			"keep five",
		},
		target = { row = 3, col = 0 },
		start_pos = { row = 3, col = 0 },
		key = "d2k",
	},
})

run_copy_paste_case({
	lesson_name = "copy_paste_lines",
	module = copy_paste_lines,
	label = "yy then p duplicates the current line below",
	yank_remap = remaps.remap_for["yy"],
	paste_remap = remaps.remap_for["p"],
	expected_ui = {
		"Copy & Paste: mm, b, B",
		"[mm] Yank line",
		"[b] Paste below",
		"[B] Paste above",
	},
	challenge = {
		snippet_lines = {
			"keep one",
			"copy me",
			"keep two",
		},
		expected_lines = {
			"keep one",
			"copy me",
			"copy me",
			"keep two",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 1, col = 0 },
		key = "p",
		yank_key = "yy",
	},
})

run_copy_paste_case({
	lesson_name = "copy_paste_lines",
	module = copy_paste_lines,
	label = "yy then P duplicates the current line above",
	yank_remap = remaps.remap_for["yy"],
	paste_remap = remaps.remap_for["P"],
	expected_ui = {
		"Copy & Paste: mm, b, B",
		"[mm] Yank line",
		"[b] Paste below",
		"[B] Paste above",
	},
	challenge = {
		snippet_lines = {
			"keep one",
			"copy me",
			"keep two",
		},
		expected_lines = {
			"keep one",
			"copy me",
			"copy me",
			"keep two",
		},
		target = { row = 1, col = 0 },
		start_pos = { row = 1, col = 0 },
		key = "P",
		yank_key = "yy",
	},
})

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_basic_operators_integration")
