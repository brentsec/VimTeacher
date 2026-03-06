-- tests/test_lessons_pool.lua
-- Tests for the shared lesson pool helper.

local pool = require("vimteacher.lessons.pool")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_lessons_pool: running...")

math.randomseed(12345)

local challenges = {
	{
		snippet_lines = { "alpha", "beta" },
		expected_lines = { "alpha", "zeta" },
		target = { row = 1, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "x",
	},
	{
		snippet_lines = { "one", "two" },
		expected_lines = { "one", "too" },
		target = { row = 1, col = 1 },
		start_pos = { row = 0, col = 0 },
		key = "r",
	},
}

local challenge_pool = pool.new(challenges)

local generated = challenge_pool.generate_challenge()
assert_test(type(generated) == "table", "generate_challenge should return a table")
assert_test(generated ~= challenges[1] and generated ~= challenges[2], "generate_challenge must deep-copy the challenge")
generated.snippet_lines[1] = "changed"
assert_test(challenges[1].snippet_lines[1] == "alpha", "generated challenge must not mutate source data")

local nav_cost = challenge_pool.nav_cost()
local vertical = nav_cost({ "alpha", "beta" }, { row = 0, col = 0 }, { row = 1, col = 0 })
assert_test(vertical == 1, "Default nav_cost should use j/k motions, got " .. tostring(vertical))

local compute_optimal = challenge_pool.nav_compute_optimal({ "h", "j", "k", "l" })
local fallback = compute_optimal({ row = 0, col = 0 }, { row = 1, col = 2 })
assert_test(fallback == 3, "Without a current snippet, nav_compute_optimal should fall back to Manhattan, got " .. fallback)

challenge_pool.generate_challenge()
local current = challenge_pool.get_current_snippet()
assert_test(type(current) == "table" and #current >= 1, "Current snippet should be tracked after generation")

local transformed_pool = pool.new(challenges, {
	track_current_snippet = false,
	transform_challenge = function(challenge)
		challenge.goal_text = "transformed"
		return challenge
	end,
})
local transformed = transformed_pool.generate_challenge()
assert_test(transformed.goal_text == "transformed", "transform_challenge should be applied")
assert_test(transformed_pool.get_current_snippet() == nil, "Current snippet should stay nil when tracking is disabled")

counter.finish("test_lessons_pool")
