-- tests/test_lessons_registry.lua
-- Coverage for lesson registry whitelisting before dynamic module load.

local lessons = require("vimteacher.lessons")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_lessons_registry: running...")

local injected_name = "not_in_registry"
local injected_module_name = "vimteacher.lessons." .. injected_name
local original_preload = package.preload[injected_module_name]
local attempted = false

package.preload[injected_module_name] = function()
	attempted = true
	return {
		title = "Injected",
		description = { "bad" },
		hint_lines = { "bad" },
		generate_challenge = function()
			return {}
		end,
	}
end

lessons.clear_cache()
local known = lessons.get_lesson("basic_movement")
assert_test(type(known) == "table", "known lessons in the registry should still load")
local hidden = lessons.get_lesson("repeat_search")
assert_test(type(hidden) == "table", "hidden but supported lessons should still load")

local blocked = lessons.get_lesson(injected_name)
assert_test(blocked == nil, "unknown lesson names should be rejected before require()")
assert_test(attempted == false, "unknown lesson names should not reach package.preload/require")

package.preload[injected_module_name] = original_preload
lessons.clear_cache()

counter.finish("test_lessons_registry")
