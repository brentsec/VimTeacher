-- tests/test_timing_smoke.lua
-- Timing smoke coverage for every lesson entry in the catalog.

local vimteacher = require("vimteacher")
local lessons = require("vimteacher.lessons")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_timing_smoke: running...")

vimteacher.setup({
	keymaps = {
		mode = "strict",
		distro = "neovim",
	},
})

for _, lesson_name in ipairs(lessons.order) do
	local lesson = lessons.get_lesson(lesson_name)
	assert_test(lesson ~= nil, "lesson registry should load " .. lesson_name)
	if lesson then
		vimteacher.start(lesson_name)
		local state = integration.runtime_state(vimteacher)
		if lesson.type == "info" then
			assert_test(integration.wait_for(function()
				return integration.buf_has_text(lesson.title)
			end, 1000), lesson_name .. " should render info lesson title")
			assert_test(state.timer_start == nil, lesson_name .. " should not start a challenge timer in info mode")
			assert_test(state.challenge_load_time == nil, lesson_name .. " should not set challenge_load_time in info mode")
		else
			assert_test(integration.wait_for(function()
				return integration.buf_has_text("Challenge 1/10")
			end, 1000), lesson_name .. " should render challenge 1")
			assert_test(type(state.timer_start) == "number" and state.timer_start > 0, lesson_name .. " should start timer on challenge load")
			assert_test(
				type(state.challenge_load_time) == "number" and state.challenge_load_time > 0,
				lesson_name .. " should set challenge_load_time on challenge load"
			)
			assert_test(
				state.challenge_load_time >= state.timer_start,
				lesson_name .. " should not backdate challenge_load_time before timer_start"
			)
			assert_test(
				(state.challenge_load_time - state.timer_start) <= 100000000,
				lesson_name .. " should initialize timer_start and challenge_load_time within 100ms"
			)
		end
	end
end

counter.finish("test_timing_smoke")
