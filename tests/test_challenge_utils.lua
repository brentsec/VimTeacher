-- tests/test_challenge_utils.lua
-- Tests for shared lesson challenge utilities.

local challenge_utils = require("vimteacher.lessons.challenge_utils")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_challenge_utils: running...")

assert_test(challenge_utils.find_nth("alpha beta alpha", "alpha", 1) == 1, "First match should start at byte 1")
assert_test(challenge_utils.find_nth("alpha beta alpha", "alpha", 2) == 12, "Second match should start at byte 12")
assert_test(challenge_utils.find_nth("abc", "z", 1) == nil, "Missing matches should return nil")

local attempts = 0
local generated = challenge_utils.generate_with_retries("test_lesson", function()
	attempts = attempts + 1
	if attempts < 3 then
		return nil
	end
	return { ok = true }
end, { max_attempts = 5 })
assert_test(generated.ok == true, "generate_with_retries should return the first successful challenge")
assert_test(attempts == 3, "generate_with_retries should stop retrying after the first success")

local ok, err = pcall(function()
	challenge_utils.generate_with_retries("failing_lesson", function()
		return nil
	end, { max_attempts = 2 })
end)
assert_test(ok == false, "generate_with_retries should error after exhausting retries")
assert_test(
	type(err) == "string" and err:find("failing_lesson", 1, true) ~= nil,
	"retry failure should name the lesson"
)

counter.finish("test_challenge_utils")
