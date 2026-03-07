-- tests/test_key_display_direct.lua
-- Direct coverage for adaptive key display text rewriting.

local key_display = require("vimteacher.key_display")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_key_display_direct: running...")

local rewritten = key_display.apply_to_text("Use [h], h, and 5h but not ghost or json.", {
	h = "z",
})
assert_test(
	rewritten == "Use [z], z, and 5z but not ghost or json.",
	"single-key replacements should respect token boundaries and count prefixes"
)

local ordered = key_display.apply_to_text("[dw] = delete word; d = delete", {
	dw = "zg",
	d = "x",
})
assert_test(
	ordered == "[zg] = delete word; x = delete",
	"multi-key replacements should take precedence over shorter overlapping tokens"
)

local prompts = key_display.apply_to_text("/target ?reverse :s/foo/bar", {
	["/"] = "y",
	["?"] = "Y",
	[":"] = ";",
})
assert_test(
	prompts == "ytarget Yreverse ;s/foo/bar",
	"prompt prefixes should be rewritten when search and command keys are remapped"
)

local lesson = {
	title = "Move with h",
	description = { "Use h then dw." },
	hint_lines = { "[h] and [dw]" },
	goal_text = "Press dw",
	sandbox_snippet = { "h dw" },
	get_title = function(ctx)
		return "Title " .. ctx.key_display.h
	end,
	get_description = function(ctx)
		return { "Desc " .. ctx.key_display.dw }
	end,
}

local view = key_display.build_lesson_view(lesson, {
	h = "z",
	dw = "zg",
})
assert_test(view.title == "Title z", "build_lesson_view should use lesson getter overrides when they succeed")
assert_test(vim.deep_equal(view.description, { "Desc zg" }), "build_lesson_view should use custom description getters")
assert_test(vim.deep_equal(view.hint_lines, { "[z] and [zg]" }), "build_lesson_view should rewrite hint lines directly")
assert_test(view.goal_text == "Press zg", "build_lesson_view should rewrite goal text directly")

view.sandbox_snippet[1] = "mutated"
assert_test(lesson.sandbox_snippet[1] == "h dw", "build_lesson_view should deep-copy sandbox snippet content")

counter.finish("test_key_display_direct")
