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
local function cleanup()
	vim.g.vimteacher_test_seed = nil
end

local ok, err = xpcall(function()
	vim.g.vimteacher_test_seed = 12345

	for _, lesson_name in ipairs(lessons.order) do
		local lesson = lessons.get_lesson(lesson_name)
		assert_test(lesson ~= nil, "lesson registry should load " .. lesson_name)
		if lesson then
			vimteacher.start(lesson_name)
			local state = integration.runtime_state(vimteacher)
			if lesson.type == "info" then
				assert_test(
					integration.wait_for_buf_text(lesson.title, 1500),
					lesson_name .. " should render info lesson title"
				)
				assert_test(state.timer_start == nil, lesson_name .. " should not start a challenge timer in info mode")
				assert_test(
					state.challenge_load_time == nil,
					lesson_name .. " should not set challenge_load_time in info mode"
				)
			else
				assert_test(
					integration.wait_for_buf_text("Challenge 1/10", 1500),
					lesson_name .. " should render challenge 1"
				)
				assert_test(
					state.timer_start == nil,
					lesson_name .. " should keep timer_start unset until the first user cursor move"
				)
				assert_test(
					state.challenge_load_time == nil,
					lesson_name .. " should keep challenge_load_time unset until the first user cursor move"
				)
			end
		end
	end
end, debug.traceback)

cleanup()

if not ok then
	error(err)
end

counter.finish("test_timing_smoke")
