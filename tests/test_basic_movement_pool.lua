-- tests/test_basic_movement_pool.lua
-- Regression coverage for the pool-backed basic movement lesson.

local optimal = require("vimteacher.optimal")
local snippets = require("vimteacher.snippets")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_basic_movement_pool: running...")

local original_pool = snippets.pool
snippets.pool = {
	{ "alpha beta", "gamma delta" },
	{ "  lead", "tail" },
}

package.loaded["vimteacher.lessons.basic_movement"] = nil
local basic = require("vimteacher.lessons.basic_movement")

local motions = { "h", "j", "k", "l", "0", "^", "$" }

local first = basic.generate_challenge()
local first_expected = optimal.nav_cost(first.snippet_lines, first.start_pos, first.target, motions)
assert_test(
	basic.compute_optimal(first.start_pos, first.target) == first_expected,
	"compute_optimal should follow the current generated snippet after the first challenge"
)

local source_copy = vim.deepcopy(snippets.pool)
first.snippet_lines[1] = "changed"
assert_test(
	vim.deep_equal(snippets.pool, source_copy),
	"basic_movement should not mutate the shared snippet pool when a generated challenge is edited"
)

local second = basic.generate_challenge()
local second_expected = optimal.nav_cost(second.snippet_lines, second.start_pos, second.target, motions)
assert_test(
	basic.compute_optimal(second.start_pos, second.target) == second_expected,
	"compute_optimal should update to the most recently generated pool challenge"
)

snippets.pool = original_pool
package.loaded["vimteacher.lessons.basic_movement"] = nil

counter.finish("test_basic_movement_pool")
