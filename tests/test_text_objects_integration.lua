-- tests/test_text_objects_integration.lua
-- Runtime integration coverage for the Text Objects section.

local vimteacher = require("vimteacher")
local delete_inside_brackets = require("vimteacher.lessons.delete_inside_brackets")
local delete_around_brackets = require("vimteacher.lessons.delete_around_brackets")
local change_inside_brackets = require("vimteacher.lessons.change_inside_brackets")
local change_around_brackets = require("vimteacher.lessons.change_around_brackets")
local quote_text_objects = require("vimteacher.lessons.quote_text_objects")
local word_text_objects = require("vimteacher.lessons.word_text_objects")
local paragraph_text_objects = require("vimteacher.lessons.paragraph_text_objects")
local text_objects_mega_review = require("vimteacher.lessons.text_objects_mega_review")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_text_objects_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "di(", remap = "zg" },
	{ canonical = "di[", remap = "z[" },
	{ canonical = "da(", remap = "z)" },
	{ canonical = "da[", remap = "z]" },
	{ canonical = "ci{", remap = "z}" },
	{ canonical = "ca(", remap = "zp" },
	{ canonical = "ci'", remap = "z;" },
	{ canonical = "ciw", remap = "zw" },
	{ canonical = "dap", remap = "zP" },
	{ canonical = 'da"', remap = 'z"' },
})

integration.configure_adaptive(vimteacher)

local function challenge_by_key(module, key)
	for _, challenge in ipairs(module._get_challenges()) do
		if challenge.key == key then
			return vim.deepcopy(challenge)
		end
	end
	error("missing challenge for key " .. key)
end

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
end

local function move_to_target(target)
	local state = integration.runtime_state(vimteacher)
	integration.move_cursor_to(state.snippet_offset + target.row + 1, target.col)
	integration.fire_cursor_moved(0)
end

local function run_delete_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_target(case.challenge.target)

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
		end, 500), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped text-object command for " .. case.label)
	end)
end

local function run_change_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_target(case.challenge.target)

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
		end, 600), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped text-object command for " .. case.label)
	end)
end

local function run_intro_case()
	vimteacher.start("intro_text_objects")
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Intro to Text Objects")
	end, 1000), "intro_text_objects should render its title")
	assert_test(integration.buf_has_text("[zg] Delete inside ()"), "intro_text_objects should render remapped delete-inside hint")
	assert_test(integration.buf_has_text("[z)] Delete around ()"), "intro_text_objects should render remapped delete-around hint")
	assert_test(integration.buf_has_text("[ci\"] Change inside"), "intro_text_objects should still render quote guidance")

	local sandbox_row = integration.find_line_index("function greet(name, age) {")
	assert_test(sandbox_row ~= nil, "intro_text_objects should render the sandbox snippet")
	if not sandbox_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { sandbox_row, 16 })
	local original_line = integration.line_at(sandbox_row)

	integration.send_sequence("di(")
	integration.wait_for(function()
		return true
	end, 80, 20)
	assert_test(integration.line_at(sandbox_row) == original_line, "canonical di( should remain blocked in intro_text_objects")

	integration.send_sequence(remaps.remap_for["di("])
	integration.fire_text_changed(0)
	assert_test(integration.wait_for(function()
		return integration.line_at(sandbox_row) == "function greet() {"
	end, 400), "remapped delete-inside command should edit the intro_text_objects sandbox")
end

run_intro_case()

run_delete_case({
	lesson_name = "delete_inside_brackets",
	module = delete_inside_brackets,
	label = "di[ uses the remapped sequence",
	remap = remaps.remap_for["di["],
	expected_ui = {
		"[z[] Delete inside []",
	},
	challenge = challenge_by_key(delete_inside_brackets, "di["),
})

run_delete_case({
	lesson_name = "delete_around_brackets",
	module = delete_around_brackets,
	label = "da[ uses the remapped sequence",
	remap = remaps.remap_for["da["],
	expected_ui = {
		"[z]] Delete around []",
	},
	challenge = challenge_by_key(delete_around_brackets, "da["),
})

run_change_case({
	lesson_name = "change_inside_brackets",
	module = change_inside_brackets,
	label = "ci{ uses the remapped sequence",
	remap = remaps.remap_for["ci{"],
	expected_ui = {
		"[z}] Change inside {}",
	},
	challenge = challenge_by_key(change_inside_brackets, "ci{"),
})

run_change_case({
	lesson_name = "change_around_brackets",
	module = change_around_brackets,
	label = "ca( uses the remapped sequence",
	remap = remaps.remap_for["ca("],
	expected_ui = {
		"[zp] Change around (",
	},
	challenge = challenge_by_key(change_around_brackets, "ca("),
})

run_change_case({
	lesson_name = "quote_text_objects",
	module = quote_text_objects,
	label = "ci' uses the remapped quote-object sequence",
	remap = remaps.remap_for["ci'"],
	expected_ui = {
		"Same keys work with single quotes: di' da' z; ca'",
	},
	challenge = challenge_by_key(quote_text_objects, "ci'"),
})

run_change_case({
	lesson_name = "word_text_objects",
	module = word_text_objects,
	label = "ciw uses the remapped word-object sequence",
	remap = remaps.remap_for["ciw"],
	expected_ui = {
		"[zw] Change inner word",
	},
	challenge = challenge_by_key(word_text_objects, "ciw"),
})

run_delete_case({
	lesson_name = "paragraph_text_objects",
	module = paragraph_text_objects,
	label = "dap uses the remapped paragraph-object sequence",
	remap = remaps.remap_for["dap"],
	expected_ui = {
		"[zP] Del block+blank",
	},
	challenge = challenge_by_key(paragraph_text_objects, "dap"),
})

run_delete_case({
	lesson_name = "text_objects_mega_review",
	module = text_objects_mega_review,
	label = 'da" uses the remapped mixed-review sequence',
	remap = remaps.remap_for['da"'],
	expected_ui = {
		"Text Objects: Mega Review",
	},
	challenge = challenge_by_key(text_objects_mega_review, 'da"'),
})

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_text_objects_integration")
