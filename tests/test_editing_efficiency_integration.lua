-- tests/test_editing_efficiency_integration.lua
-- Runtime integration coverage for the Editing Efficiency section.

local vimteacher = require("vimteacher")
local repeat_power = require("vimteacher.lessons.repeat_power")
local macro_repetition = require("vimteacher.lessons.macro_repetition")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_editing_efficiency_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "x", remap = "b" },
	{ canonical = ".", remap = "n" },
	{ canonical = "qa", remap = "rg" },
	{ canonical = "q", remap = "R" },
	{ canonical = "@a", remap = "tt" },
	{ canonical = "@@", remap = "TT" },
})

integration.configure_adaptive(vimteacher)

local function find_repeat_power_challenge()
	for _, challenge in ipairs(repeat_power._get_challenges()) do
		if challenge.key == "x" then
			return vim.deepcopy(challenge)
		end
	end
	error("missing repeat_power x challenge")
end

local function find_macro_challenge(predicate)
	for _, challenge in ipairs(macro_repetition._get_challenges()) do
		if predicate(challenge) then
			return vim.deepcopy(challenge)
		end
	end
	error("missing macro challenge")
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

local function move_to_phase_target(phase)
	local state = integration.runtime_state(vimteacher)
	integration.move_cursor_to(state.snippet_offset + phase.target.row + 1, phase.target.col)
	integration.fire_cursor_moved(0)
end

local function wait_for_macro_idle(timeout_ms)
	return integration.wait_for(function()
		return vim.fn.reg_recording() == "" and vim.fn.reg_executing() == ""
	end, timeout_ms or 600, 20)
end

local function run_repeat_power_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_phase_target(case.challenge.phases[1])

		integration.send_sequence(case.challenge.key)
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(
			integration.snippet_matches(vimteacher, case.challenge.snippet_lines),
			"canonical " .. case.challenge.key .. " should remain blocked for " .. case.label
		)

		integration.send_sequence(case.first_remap)
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.phases[1].expected_lines)
		end, 500), case.lesson_name .. " should apply the first remapped change for " .. case.label)

		move_to_phase_target(case.challenge.phases[2])

		integration.send_sequence(".")
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(
			integration.snippet_matches(vimteacher, case.challenge.phases[1].expected_lines),
			"canonical . should remain blocked for " .. case.label
		)

		integration.send_sequence(case.repeat_remap)
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 600), case.lesson_name .. " should repeat the change via remapped dot for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after the repeated change for " .. case.label)
	end)
end

local function run_macro_repeat_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)
		move_to_phase_target(case.challenge.phases[1])

		integration.send_sequence("q")
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(vim.fn.reg_recording() == "" and vim.fn.mode() == "n", "canonical q should remain blocked for " .. case.label)

		integration.send_sequence(remaps.remap_for["qa"])
		assert_test(integration.wait_for(function()
			return vim.fn.reg_recording() == "a"
		end, 200), case.lesson_name .. " should start recording with the remapped qa sequence for " .. case.label)

		integration.send_sequence(case.record_sequence)
		integration.wait_for(function()
			return true
		end, 80, 20)
		integration.send_sequence(remaps.remap_for["q"])
		assert_test(integration.wait_for(function()
			return vim.fn.reg_recording() == ""
		end, 200), case.lesson_name .. " should stop recording with the remapped q key for " .. case.label)
		wait_for_macro_idle(400)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			local state = integration.runtime_state(vimteacher)
			return integration.snippet_matches(vimteacher, case.challenge.phases[1].expected_lines)
				and state.current_challenge.phase_index == 2
		end, 1200), case.lesson_name .. " should apply the recorded edit for " .. case.label)

		move_to_phase_target(case.challenge.phases[2])
		integration.send_sequence(case.phase2_sequence)
		integration.wait_for(function()
			return true
		end, 120, 20)
		wait_for_macro_idle(600)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			local state = integration.runtime_state(vimteacher)
			local phase_ok = case.challenge.phases[3] and state.current_challenge.phase_index == 3
				or (not case.challenge.phases[3])
			return integration.snippet_matches(vimteacher, case.challenge.phases[2].expected_lines) and phase_ok
		end, 1200), case.lesson_name .. " should replay the macro with remapped keys for " .. case.label)

		if case.challenge.phases[3] then
			move_to_phase_target(case.challenge.phases[3])
			integration.send_sequence(case.phase3_sequence)
			integration.wait_for(function()
				return true
			end, 120, 20)
			wait_for_macro_idle(600)
			integration.fire_text_changed(0)
			assert_test(integration.wait_for(function()
				return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
			end, 1200), case.lesson_name .. " should repeat the macro again with remapped @@ for " .. case.label)
		end

		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped macro replay for " .. case.label)
	end)
end

run_repeat_power_case({
	lesson_name = "repeat_power",
	module = repeat_power,
	label = "x and . use the remapped keys across both phases",
	first_remap = remaps.remap_for["x"],
	repeat_remap = remaps.remap_for["."],
	expected_ui = {
		"[b] Delete char",
		"[n] Repeat last change",
	},
	challenge = find_repeat_power_challenge(),
})

run_macro_repeat_case({
	lesson_name = "macro_repetition",
	module = macro_repetition,
	label = "qa, q, @a, and @@ use the remapped macro keys",
	record_sequence = remaps.remap_for["x"],
	phase2_sequence = remaps.remap_for["@a"],
	phase3_sequence = remaps.remap_for["@@"],
	expected_ui = {
		"Macros for Repetition: rg, R, tt, TT",
		"[rg] Record in a",
		"[R] Stop recording",
		"[tt] Run a",
		"[TT] Repeat last macro",
	},
	challenge = find_macro_challenge(function(challenge)
		return #challenge.phases == 3 and challenge.phases[3].goal_text:find("@@", 1, true) ~= nil
	end),
})

run_macro_repeat_case({
	lesson_name = "macro_repetition",
	module = macro_repetition,
	label = "count@a uses the remapped replay key with an actual count prefix",
	record_sequence = remaps.remap_for["x"] .. "j",
	phase2_sequence = tostring(#find_macro_challenge(function(challenge)
		return #challenge.phases == 2 and challenge.phases[2].goal_text:match("%d+@a") ~= nil
	end)._macro_targets - 1) .. remaps.remap_for["@a"],
	expected_ui = {
		"[tt] Run a",
	},
	challenge = find_macro_challenge(function(challenge)
		return #challenge.phases == 2 and challenge.phases[2].goal_text:match("%d+@a") ~= nil
	end),
})

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_editing_efficiency_integration")
