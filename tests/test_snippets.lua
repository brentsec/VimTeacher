-- tests/test_snippets.lua
-- Tests for the snippet pool and selection algorithm

local snippets = require("vimteacher.snippets")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_snippets: running...")

-- Test 1: Pool contains at least 10 snippets
assert_test(#snippets.pool >= 10, "Pool must have at least 10 snippets, got " .. #snippets.pool)

-- Test 2: Every snippet has 5-10 lines
for i, snippet in ipairs(snippets.pool) do
	assert_test(#snippet >= 5 and #snippet <= 10, "Snippet " .. i .. " has " .. #snippet .. " lines (expected 5-10)")
end

-- Test 3: Every snippet has at least 15 non-whitespace positions
for i, snippet in ipairs(snippets.pool) do
	local count = 0
	for _, line in ipairs(snippet) do
		for c = 1, #line do
			local char = line:sub(c, c)
			if char ~= " " and char ~= "\t" then
				count = count + 1
			end
		end
	end
	assert_test(count >= 15, "Snippet " .. i .. " has only " .. count .. " valid positions (need >= 15)")
end

-- Test 4: get_random returns a table of strings
snippets.reset_recent()
local s = snippets.get_random()
assert_test(type(s) == "table", "get_random must return a table")
assert_test(type(s[1]) == "string", "Snippet lines must be strings, got " .. type(s[1]))

-- Test 5: No immediate repeats over 20 calls
snippets.reset_recent()
local prev_first_line = nil
local repeat_count = 0
for _ = 1, 20 do
	local sn = snippets.get_random()
	if sn[1] == prev_first_line then
		repeat_count = repeat_count + 1
	end
	prev_first_line = sn[1]
end
assert_test(repeat_count == 0, "Got " .. repeat_count .. " immediate repeats in 20 draws")

-- Test 6: get_random returns a COPY (modifying it does not affect pool)
snippets.reset_recent()
local original_first = snippets.pool[1][1]
local drawn = snippets.get_random()
drawn[1] = "MODIFIED"
assert_test(snippets.pool[1][1] == original_first, "get_random must return a copy, not a reference")

-- Test 7: reset_recent works
snippets.reset_recent()
snippets.get_random()
snippets.reset_recent()
-- After reset, no tracking should exist, so any snippet is available
local b = snippets.get_random()
assert_test(type(b) == "table", "get_random works after reset_recent")

counter.finish("test_snippets")
