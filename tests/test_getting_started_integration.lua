-- tests/test_getting_started_integration.lua
-- Runtime integration coverage for adaptive keymaps in Getting Started lessons.

local vimteacher = require("vimteacher")
local basic_movement = require("vimteacher.lessons.basic_movement")
local word_movement = require("vimteacher.lessons.word_movement")
local insert_mode = require("vimteacher.lessons.insert_mode")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_getting_started_integration: running...")

local remap_pairs = {
	{ canonical = "h", remap = "z" },
	{ canonical = "j", remap = "x" },
	{ canonical = "k", remap = "c" },
	{ canonical = "l", remap = "v" },
	{ canonical = "w", remap = "g" },
	{ canonical = "e", remap = "y" },
	{ canonical = "b", remap = "n" },
	{ canonical = "i", remap = "u" },
	{ canonical = "a", remap = "p" },
}

local remaps = integration.install_normal_remaps(remap_pairs)
local remap_for = remaps.remap_for
integration.configure_adaptive(vimteacher)

local function assert_recorded_time_below(label, max_recorded_secs)
	if not max_recorded_secs then
		return
	end
	local state = integration.runtime_state(vimteacher)
	assert_test(
		#state.session_challenges >= 1 and state.session_challenges[1].time <= max_recorded_secs,
		label
			.. " should not include pre-move delay in challenge time (expected <= "
			.. max_recorded_secs
			.. "s, got "
			.. string.format("%.3f", (state.session_challenges[1] and state.session_challenges[1].time) or -1)
			.. "s)"
	)
end

local function run_intro_modes_case()
	vimteacher.start("intro_modes")

	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Intro to Modes")
	end, 1000), "intro_modes should render its title")
	assert_test(integration.buf_has_text("[u] Enter insert mode"), "intro_modes should render remapped insert hint")

	local sandbox_row = integration.find_line_index("function hello()")
	assert_test(sandbox_row ~= nil, "intro_modes should render sandbox snippet")
	if not sandbox_row then
		return
	end

	vim.api.nvim_win_set_cursor(0, { sandbox_row, 0 })
	local base_line = integration.line_at(sandbox_row)
	assert_test(type(base_line) == "string" and #base_line > 2, "intro_modes sandbox line should be usable for movement")

	integration.send_key("l")
	integration.wait_for(function()
		return true
	end, 60, 20)
	local cur_after_blocked = integration.current_cursor()
	assert_test(cur_after_blocked[1] == sandbox_row and cur_after_blocked[2] == 0, "canonical l should stay blocked")

	integration.send_key(remap_for["l"])
	assert_test(integration.wait_for(function()
		return integration.current_cursor()[2] == 1
	end, 300), "remapped right key should move one column right in intro_modes")

	integration.send_key(remap_for["j"])
	assert_test(integration.wait_for(function()
		return integration.current_cursor()[1] == sandbox_row + 1
	end, 300), "remapped down key should move one row down in intro_modes")

	integration.send_key(remap_for["k"])
	assert_test(integration.wait_for(function()
		return integration.current_cursor()[1] == sandbox_row
	end, 300), "remapped up key should move one row up in intro_modes")

	integration.send_key(remap_for["h"])
	assert_test(integration.wait_for(function()
		return integration.current_cursor()[2] == 0
	end, 300), "remapped left key should move one column left in intro_modes")

	integration.send_key("i")
	integration.wait_for(function()
		return true
	end, 60, 20)
	assert_test(integration.line_at(sandbox_row) == base_line, "canonical i should stay blocked in intro_modes")

	integration.perform_insert_sequence(remap_for["i"], "Z")
	assert_test(integration.wait_for(function()
		return integration.line_at(sandbox_row) == "Z" .. base_line
	end, 300), "typing through remapped insert key should modify the intro_modes sandbox")
end

local function run_basic_movement_case(case)
	integration.with_overridden_generate(basic_movement, {
		snippet_lines = {
			"abc",
			"def",
			"ghi",
		},
		target = case.target,
		start_pos = case.start_pos,
	}, function()
		vimteacher.start("basic_movement")
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 1/10")
		end, 1000), "basic_movement should render challenge 1 for " .. case.label)
		assert_test(integration.buf_has_text("Move to target using z/x/c/v"), "basic_movement should render remapped helper text")
		integration.prime_pending_cursor_event()

		local snippet_row = integration.find_line_index("abc")
		assert_test(snippet_row ~= nil, "basic_movement should render deterministic snippet for " .. case.label)
		if not snippet_row then
			return
		end

		local expected_start_row = snippet_row + case.start_pos.row
		local expected_target_row = snippet_row + case.target.row
		local cur0 = integration.current_cursor()
		assert_test(
			cur0[1] == expected_start_row and cur0[2] == case.start_pos.col,
			"basic_movement should place cursor at deterministic start for " .. case.label
		)
		local state = integration.runtime_state(vimteacher)
		assert_test(state.timer_start == nil, "basic_movement should not start timing before the first move for " .. case.label)
		if case.delay_ms then
			vim.wait(case.delay_ms, function()
				return false
			end, case.delay_ms)
			assert_test(state.timer_start == nil, "basic_movement should keep timing off during pre-move delay for " .. case.label)
		end

		integration.send_key(case.canonical)
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_cursor_moved(0)
		local blocked_cursor = integration.current_cursor()
		assert_test(
			blocked_cursor[1] == cur0[1] and blocked_cursor[2] == cur0[2],
			"canonical " .. case.canonical .. " should remain blocked in basic_movement"
		)
		assert_test(
			integration.buf_has_text("Challenge 1/10"),
			"basic_movement should stay on challenge 1 after blocked " .. case.canonical
		)

		integration.send_key(case.remap)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == expected_target_row and cur[2] == case.target.col
		end, 300), "remapped " .. case.remap .. " should move to target for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_test(state.timer_start ~= nil, "basic_movement should start timing on the first actual move for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1500), "basic_movement should advance after remapped " .. case.remap .. " for " .. case.label)
		assert_recorded_time_below("basic_movement " .. case.label, case.max_recorded_secs)
	end)
end

local function run_word_movement_case(case)
	integration.with_overridden_generate(word_movement, {
		snippet_lines = { case.snippet },
		target = case.target,
		start_pos = case.start_pos,
	}, function()
		vimteacher.start("word_movement")
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 1/10")
		end, 1000), "word_movement should render challenge 1 for " .. case.label)
		assert_test(integration.buf_has_text("Move to target using g/y/n"), "word_movement should render remapped helper text")
		integration.prime_pending_cursor_event()

		local snippet_row = integration.find_line_index(case.snippet)
		assert_test(snippet_row ~= nil, "word_movement should render deterministic snippet for " .. case.label)
		if not snippet_row then
			return
		end

		local expected_start_row = snippet_row + case.start_pos.row
		local expected_target_row = snippet_row + case.target.row
		local cur0 = integration.current_cursor()
		assert_test(
			cur0[1] == expected_start_row and cur0[2] == case.start_pos.col,
			"word_movement should place cursor at deterministic start for " .. case.label
		)

		integration.send_key(case.canonical)
		integration.wait_for(function()
			return true
		end, 60, 20)
		integration.fire_cursor_moved(0)
		local blocked_cursor = integration.current_cursor()
		assert_test(
			blocked_cursor[1] == cur0[1] and blocked_cursor[2] == cur0[2],
			"canonical " .. case.canonical .. " should remain blocked in word_movement"
		)

		integration.send_key(case.remap)
		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == expected_target_row and cur[2] == case.target.col
		end, 300), "remapped " .. case.remap .. " should move to target for " .. case.label)
		integration.fire_cursor_moved(0)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), "word_movement should advance after remapped " .. case.remap .. " for " .. case.label)
	end)
end

local function run_insert_mode_case(case)
	integration.with_overridden_generate(insert_mode, case.challenge, function()
		vimteacher.start("insert_mode")
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 1/10")
		end, 1000), "insert_mode should render challenge 1 for " .. case.label)
		assert_test(integration.buf_has_text("Insert Mode: u, p"), "insert_mode should render remapped title")
		assert_test(
			integration.buf_has_text("[u] Insert before cursor  [p] Append after cursor"),
			"insert_mode should render remapped hints"
		)

		local snippet_row = integration.find_line_index(case.challenge.snippet_lines[1])
		assert_test(snippet_row ~= nil, "insert_mode should render deterministic snippet for " .. case.label)
		if not snippet_row then
			return
		end

		local expected_start_row = snippet_row + case.challenge.start_pos.row
		local cur0 = integration.current_cursor()
		assert_test(
			cur0[1] == expected_start_row and cur0[2] == case.challenge.start_pos.col,
			"insert_mode should place cursor at deterministic start for " .. case.label
		)
		local state = integration.runtime_state(vimteacher)
		assert_test(state.timer_start == nil, "insert_mode should not start timing before any cursor movement for " .. case.label)

		local original_line = integration.line_at(snippet_row + case.challenge.target.row)
		integration.send_key(case.challenge.key)
		integration.wait_for(function()
			return true
		end, 60, 20)
		local after_blocked_cursor = integration.current_cursor()
		assert_test(
			integration.line_at(snippet_row + case.challenge.target.row) == original_line,
			"canonical " .. case.challenge.key .. " should remain blocked"
		)
		assert_test(
			after_blocked_cursor[1] == cur0[1] and after_blocked_cursor[2] == cur0[2],
			"canonical " .. case.challenge.key .. " should not move the cursor for " .. case.label
		)
		if case.delay_ms then
			vim.wait(case.delay_ms, function()
				return false
			end, case.delay_ms)
			assert_test(state.timer_start == nil, "insert_mode should keep timing off while the user has not moved the cursor for " .. case.label)
		end

		integration.perform_insert_sequence(case.remap, case.challenge.char)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text(case.expected_line)
		end, 300), "insert_mode should apply the expected text edit for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1500), "insert_mode should advance after correct remapped edit for " .. case.label)
		assert_test(state.timer_start == nil, "insert_mode should not start timing when the cursor never moved for " .. case.label)
		assert_recorded_time_below("insert_mode " .. case.label, case.max_recorded_secs)
	end)
end

run_intro_modes_case()

for _, case in ipairs({
	{
		label = "left",
		canonical = "h",
		remap = remap_for["h"],
		start_pos = { row = 1, col = 1 },
		target = { row = 1, col = 0 },
		delay_ms = 1100,
		max_recorded_secs = 0.8,
	},
	{
		label = "down",
		canonical = "j",
		remap = remap_for["j"],
		start_pos = { row = 0, col = 1 },
		target = { row = 1, col = 1 },
	},
	{
		label = "up",
		canonical = "k",
		remap = remap_for["k"],
		start_pos = { row = 1, col = 1 },
		target = { row = 0, col = 1 },
	},
	{
		label = "right",
		canonical = "l",
		remap = remap_for["l"],
		start_pos = { row = 1, col = 1 },
		target = { row = 1, col = 2 },
	},
}) do
	run_basic_movement_case(case)
end

for _, case in ipairs({
	{
		label = "next word",
		canonical = "w",
		remap = remap_for["w"],
		snippet = "one two three",
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 4 },
	},
	{
		label = "end of word",
		canonical = "e",
		remap = remap_for["e"],
		snippet = "one two three",
		start_pos = { row = 0, col = 0 },
		target = { row = 0, col = 2 },
	},
	{
		label = "back a word",
		canonical = "b",
		remap = remap_for["b"],
		snippet = "one two three",
		start_pos = { row = 0, col = 4 },
		target = { row = 0, col = 0 },
	},
}) do
	run_word_movement_case(case)
end

run_insert_mode_case({
	label = "insert before cursor",
	remap = remap_for["i"],
	expected_line = "testing",
	delay_ms = 1100,
	max_recorded_secs = 0.2,
	challenge = {
		snippet_lines = { "esting" },
		expected_lines = { "testing" },
		target = { row = 0, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "i",
		char = "t",
	},
})

run_insert_mode_case({
	label = "append after cursor",
	remap = remap_for["a"],
	expected_line = "log",
	challenge = {
		snippet_lines = { "lo" },
		expected_lines = { "log" },
		target = { row = 0, col = 1 },
		start_pos = { row = 0, col = 1 },
		key = "a",
		char = "g",
	},
})

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_getting_started_integration")
