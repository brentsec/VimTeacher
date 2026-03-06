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

counter.finish("test_challenge_utils")
