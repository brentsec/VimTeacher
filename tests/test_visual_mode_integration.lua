-- tests/test_visual_mode_integration.lua
-- Runtime integration coverage for the Visual Mode section.

local vimteacher = require("vimteacher")
local visual_mode_operators = require("vimteacher.lessons.visual_mode_operators")
local visual_line_mode = require("vimteacher.lessons.visual_line_mode")
local switch_selection_ends = require("vimteacher.lessons.switch_selection_ends")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_visual_mode_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "v", remap = "z" },
	{ canonical = "V", remap = "Z" },
	{ canonical = "o", remap = "u" },
	{ canonical = "d", remap = "x" },
	{ canonical = "c", remap = "s" },
})
local visual_mode_remaps = integration.install_mode_maps("x", {
	{ canonical = "o", remap = "u" },
	{ canonical = "d", remap = "x" },
	{ canonical = "c", remap = "s" },
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

local function horizontal_motion(from_col, to_col)
	if to_col > from_col then
		return string.rep("l", to_col - from_col)
	end
	if to_col < from_col then
		return string.rep("h", from_col - to_col)
	end
	return ""
end

local function run_intro_case()
	vimteacher.start("intro_visual_mode")
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Intro to Visual Mode")
	end, 1000), "intro_visual_mode should render its title")
	assert_test(integration.buf_has_text("[z] Start visual mode"), "intro_visual_mode should render the remapped visual-mode hint")

	local sandbox_row = integration.find_line_index('const items = ["apple", "banana", "cherry"];')
	assert_test(sandbox_row ~= nil, "intro_visual_mode should render the sandbox snippet")
	if not sandbox_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { sandbox_row, 6 })
	integration.send_sequence("v")
	integration.wait_for(function()
		return true
	end, 60, 20)
	assert_test(vim.fn.mode() == "n", "canonical v should remain blocked in intro_visual_mode")

	integration.send_sequence(remaps.remap_for["v"])
	assert_test(integration.wait_for(function()
		return vim.fn.mode() == "v"
	end, 200), "remapped visual-mode key should enter visual mode in intro_visual_mode")
	integration.send_sequence("<Esc>")
end

local function run_visual_operator_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_target(case.challenge.target)

		integration.send_sequence("v")
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(vim.fn.mode() == "n", "canonical v should remain blocked for " .. case.label)

		integration.send_sequence(remaps.remap_for["v"])
		assert_test(integration.wait_for(function()
			return vim.fn.mode() == "v"
		end, 200), case.lesson_name .. " should enter visual mode with the remapped key for " .. case.label)

		local motion = horizontal_motion(case.challenge.target.col, case.challenge.select_end.col)
		if motion ~= "" then
			integration.send_sequence(motion)
			integration.wait_for(function()
				return true
			end, 60, 20)
		end

		if case.exec == "delete" then
			integration.send_sequence(remaps.remap_for["d"])
			integration.wait_for(function()
				return true
			end, 60, 20)
			integration.fire_text_changed(0)
		else
			integration.send_sequence(remaps.remap_for["c"], "m")
			integration.wait_for(function()
				return true
			end, 60, 20)
			integration.send_sequence(case.challenge.char .. "<Esc>", "mtx")
		end

		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 700), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped visual edit for " .. case.label)
	end)
end

local function run_visual_line_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_target(case.challenge.target)

		integration.send_sequence("V")
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(vim.fn.mode() == "n", "canonical V should remain blocked for " .. case.label)

		integration.send_sequence(remaps.remap_for["V"])
		assert_test(integration.wait_for(function()
			return vim.fn.mode() == "V"
		end, 200), case.lesson_name .. " should enter visual-line mode with the remapped key for " .. case.label)

		local motion = case.challenge.key:sub(2, -2)
		if motion ~= "" then
			integration.send_sequence(motion)
			integration.wait_for(function()
				return true
			end, 60, 20)
		end

		if case.exec == "delete" then
			integration.send_sequence(remaps.remap_for["d"])
			integration.wait_for(function()
				return true
			end, 60, 20)
			integration.fire_text_changed(0)
		else
			integration.send_sequence(remaps.remap_for["c"], "m")
			integration.wait_for(function()
				return true
			end, 60, 20)
			integration.send_sequence(case.challenge.char .. "<Esc>", "mtx")
		end

		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 700), case.lesson_name .. " should apply the expected edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped visual-line edit for " .. case.label)
	end)
end

local function run_switch_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_target(case.challenge.target)

		local state = integration.runtime_state(vimteacher)
		local target_abs_row = state.snippet_offset + case.challenge.target.row + 1

		integration.send_sequence(remaps.remap_for["v"])
		assert_test(integration.wait_for(function()
			return vim.fn.mode() == "v"
		end, 200), case.lesson_name .. " should enter visual mode with the remapped key for " .. case.label)

		local motion = horizontal_motion(case.challenge.target.col, case.challenge.select_end.col)
		if motion ~= "" then
			integration.send_sequence(motion)
			integration.wait_for(function()
				return true
			end, 60, 20)
		end

		integration.send_sequence(remaps.remap_for["o"])
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == target_abs_row and cur[2] == case.challenge.target.col
		end, 200), case.lesson_name .. " should switch the active selection end with the remapped o key for " .. case.label)

		integration.send_sequence(remaps.remap_for["d"])
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_text_changed(0)

		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 700), case.lesson_name .. " should apply the expected delete after switching selection ends for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after the remapped vod flow for " .. case.label)
	end)
end

run_intro_case()

run_visual_operator_case({
	lesson_name = "visual_mode_operators",
	module = visual_mode_operators,
	label = "v and d use the remapped visual-operator keys",
	exec = "delete",
	expected_ui = {
		"[z] Visual mode",
		"[x] Delete selection",
	},
	challenge = challenge_by_key(visual_mode_operators, "vd"),
})

run_visual_operator_case({
	lesson_name = "visual_mode_operators",
	module = visual_mode_operators,
	label = "v and c use the remapped visual-change keys",
	exec = "change",
	expected_ui = {
		"[z] Visual mode",
		"[s] Change selection",
	},
	challenge = challenge_by_key(visual_mode_operators, "vc"),
})

run_visual_line_case({
	lesson_name = "visual_line_mode",
	module = visual_line_mode,
	label = "V and d use the remapped visual-line keys",
	exec = "delete",
	expected_ui = {
		"[Z] Visual line",
		"[x] Delete",
	},
	challenge = challenge_by_key(visual_line_mode, "Vjd"),
})

run_switch_case({
	lesson_name = "switch_selection_ends",
	module = switch_selection_ends,
	label = "o uses the remapped switch-selection key",
	expected_ui = {
		"[z] Visual mode",
		"[u] Switch selection end",
		"[x] Delete selection",
	},
	challenge = challenge_by_key(switch_selection_ends, "vod"),
})

integration.clear_maps(remaps.cleanup_keys)
integration.clear_mode_maps("x", visual_mode_remaps.cleanup_keys)
counter.finish("test_visual_mode_integration")
