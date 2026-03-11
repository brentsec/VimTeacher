-- tests/test_timer_visibility_integration.lua
-- Integration coverage for keeping the timer visible after the first move.

local vimteacher = require("vimteacher")
local highlight = require("vimteacher.highlight")
local small_edits = require("vimteacher.lessons.small_edits")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_timer_visibility_integration: running...")

vimteacher.setup({
	keymaps = {
		mode = "strict",
		distro = "neovim",
	},
})

local function timer_marks(buf)
	return vim.api.nvim_buf_get_extmarks(buf, highlight.ns_timer, 0, -1, { details = true })
end

integration.with_overridden_generate(small_edits, {
	snippet_lines = { "debug" },
	expected_lines = { "debug" },
	target = { row = 0, col = 4 },
	start_pos = { row = 0, col = 0 },
	key = "x",
}, function()
	vimteacher.start("small_edits")
	assert_test(
		integration.wait_for_buf_text("Challenge 1/10", 1000),
		"small_edits should render challenge 1 for timer visibility coverage"
	)

	local state = integration.runtime_state(vimteacher)
	local before = timer_marks(state.buf)
	assert_test(#before == 1, "challenge render should show a timer before the first move")
	if #before ~= 1 then
		return
	end
	assert_test(
		before[1][4].virt_text[1][1] == "  00:00",
		"challenge render should start with a visible 00:00 timer"
	)

	integration.prime_pending_cursor_event()
	integration.send_key("l")
	assert_test(
		integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[2] == 1
		end, 300),
		"the first move should move the cursor without completing the challenge"
	)
	integration.fire_cursor_moved(state.buf)
	integration.drain(120)

	assert_test(state.mode == "playing", "the timer visibility case should still be in the active challenge")
	assert_test(state.challenge_num == 1, "the timer visibility case should not complete the challenge after one move")
	assert_test(state.timer_start ~= nil, "the first move should start challenge timing")

	local after_move = timer_marks(state.buf)
	assert_test(#after_move == 1, "the timer should remain visible immediately after the first move")
	assert_test(
		#after_move == 1 and after_move[1][4].virt_text[1][1] == "  00:00",
		"the first move should show 00:00 immediately"
	)

	assert_test(
		integration.wait_for(function()
			local marks = timer_marks(state.buf)
			return #marks == 1 and marks[1][4].virt_text[1][1] == "  00:01"
		end, 4000, 25),
		"the timer should eventually advance to 00:01 after the first move"
	)
end)

counter.finish("test_timer_visibility_integration")
