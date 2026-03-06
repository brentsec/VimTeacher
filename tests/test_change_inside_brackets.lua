-- tests/test_change_inside_brackets.lua
-- Tests for the change inside brackets lesson module (ci(, ci[, ci{)

local change_inside_brackets = require("vimteacher.lessons.change_inside_brackets")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_change_inside_brackets: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(change_inside_brackets.title ~= nil, "Missing title")
assert_test(type(change_inside_brackets.description) == "table", "description must be table")
assert_test(type(change_inside_brackets.hint_lines) == "table", "hint_lines must be table")
assert_test(type(change_inside_brackets.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(
	change_inside_brackets.type == "insert",
	"type must be 'insert', got " .. tostring(change_inside_brackets.type)
)
assert_test(type(change_inside_brackets.allowed_keys) == "table", "allowed_keys must be table")
assert_test(change_inside_brackets.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#change_inside_brackets.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #change_inside_brackets.allowed_keys
)
assert_test(change_inside_brackets.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Test 3: compute_optimal works (Manhattan distance)
local opt1 = change_inside_brackets.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Row 0,Col 0 to Row 3,Col 5 should be 8, got " .. opt1)

local opt2 = change_inside_brackets.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 0, "Same position should be 0, got " .. opt2)

local opt3 = change_inside_brackets.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 10, "Same row, col 0 to 10 should be 10, got " .. opt3)

local opt4 = change_inside_brackets.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 5 })
assert_test(opt4 == 3, "Row 0 to 3, same col should be 3, got " .. opt4)

local opt5 = change_inside_brackets.compute_optimal({ row = 1, col = 3 }, { row = 4, col = 8 })
assert_test(opt5 == 8, "Row 1,Col 3 to Row 4,Col 8 should be 8, got " .. opt5)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_change_inside_brackets")
local challenge = change_inside_brackets.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")
assert_test(
	challenge.key == "ci(" or challenge.key == "ci[" or challenge.key == "ci{",
	"key must be 'ci(', 'ci[', or 'ci{', got '" .. tostring(challenge.key) .. "'"
)

-- Test 5: snippet_lines and expected_lines have same length (no line additions)
assert_test(
	#challenge.snippet_lines == #challenge.expected_lines,
	"snippet_lines and expected_lines must have same length"
)

-- Test 6: snippet_lines and expected_lines differ (there's something to fix)
local lines_differ = false
for i = 1, #challenge.snippet_lines do
	if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
		lines_differ = true
		break
	end
end
assert_test(lines_differ, "snippet_lines and expected_lines must differ")

-- Test 7: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
	challenge.target.row < #challenge.snippet_lines,
	"target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)
local target_line = challenge.snippet_lines[challenge.target.row + 1]
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(
	challenge.target.col < #target_line,
	"target.col out of bounds: " .. challenge.target.col .. " >= " .. #target_line
)

-- Test 8: Target is on a non-whitespace character
local target_char = target_line:sub(challenge.target.col + 1, challenge.target.col + 1)
assert_test(target_char ~= " " and target_char ~= "\t", "Target must be on non-whitespace, got '" .. target_char .. "'")

-- Test 9: Start position has Manhattan distance >= 1 from target
if challenge.start_pos then
	local dist = math.abs(challenge.start_pos.row - challenge.target.row)
		+ math.abs(challenge.start_pos.col - challenge.target.col)
	assert_test(dist >= 1, "Start must be >= 1 Manhattan distance from target, got " .. dist)
end

-- Test 10: CRITICAL — Simulated edit correctness for ALL challenges
-- ci(, ci[, ci{ replace contents between brackets with char field, keeping brackets
local challenges = change_inside_brackets._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")
	assert_test(
		c.key == "ci(" or c.key == "ci[" or c.key == "ci{",
		"Challenge " .. idx .. ": key must be 'ci(', 'ci[', or 'ci{', got '" .. tostring(c.key) .. "'"
	)

	-- Verify same line count (ci operations don't add/remove lines)
	assert_test(
		#c.expected_lines == #c.snippet_lines,
		"Challenge "
			.. idx
			.. ": expected_lines count "
			.. #c.expected_lines
			.. " must equal snippet_lines count "
			.. #c.snippet_lines
	)

	-- Verify target is within snippet bounds
	assert_test(
		c.target.row < #c.snippet_lines,
		"Challenge " .. idx .. ": target.row " .. c.target.row .. " >= " .. #c.snippet_lines
	)
	local sline = c.snippet_lines[c.target.row + 1]
	assert_test(
		c.target.col < #sline,
		"Challenge " .. idx .. ": target.col " .. c.target.col .. " >= " .. #sline .. " (line: '" .. sline .. "')"
	)

	-- Simulate the edit: find brackets around target, replace contents with char
	local edited = vim.deepcopy(c.snippet_lines)
	local line = edited[c.target.row + 1]
	local col = c.target.col

	-- Determine bracket type from key
	local open_bracket, close_bracket
	if c.key == "ci(" then
		open_bracket, close_bracket = "(", ")"
	elseif c.key == "ci[" then
		open_bracket, close_bracket = "[", "]"
	elseif c.key == "ci{" then
		open_bracket, close_bracket = "{", "}"
	end

	-- Find opening bracket (search backward from target)
	local open_pos = nil
	for i = col, 0, -1 do
		if line:sub(i + 1, i + 1) == open_bracket then
			open_pos = i
			break
		end
	end

	-- Find closing bracket (search forward from target)
	local close_pos = nil
	for i = col, #line - 1 do
		if line:sub(i + 1, i + 1) == close_bracket then
			close_pos = i
			break
		end
	end

	assert_test(
		open_pos ~= nil,
		"Challenge " .. idx .. ": Could not find opening bracket '" .. open_bracket .. "' in line: '" .. line .. "'"
	)
	assert_test(
		close_pos ~= nil,
		"Challenge " .. idx .. ": Could not find closing bracket '" .. close_bracket .. "' in line: '" .. line .. "'"
	)

	if open_pos and close_pos then
		-- Replace contents between brackets with char, keeping brackets
		edited[c.target.row + 1] = line:sub(1, open_pos + 1) .. c.char .. line:sub(close_pos + 1)

		-- Compare edited snippet to expected_lines
		assert_test(
			#edited == #c.expected_lines,
			"Challenge " .. idx .. ": edited line count " .. #edited .. " != expected " .. #c.expected_lines
		)
		for i = 1, #c.expected_lines do
			assert_test(
				edited[i] == c.expected_lines[i],
				"Challenge "
					.. idx
					.. " line "
					.. i
					.. ": got '"
					.. edited[i]
					.. "' expected '"
					.. c.expected_lines[i]
					.. "'"
			)
		end
	end
end

-- Test 11: Run 50 generations without crashes
for i = 1, 50 do
	local ch = change_inside_brackets.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Test 12: Bracket space normalization tolerates natural spacing
local init_mod = require("vimteacher")
local normalize = init_mod._normalize_bracket_spaces

-- Spaces after opening brackets
assert_test(normalize("{  hello }") == "{hello}", "Double space after { should normalize")
assert_test(normalize("( value )") == "(value)", "Spaces in parens should normalize")
assert_test(normalize("[ item ]") == "[item]", "Spaces in square brackets should normalize")

-- No brackets: unchanged
assert_test(normalize("no brackets here") == "no brackets here", "No brackets = no change")

-- Only opening space
assert_test(normalize("{ hello}") == "{hello}", "Only opening space should normalize")

-- Only closing space
assert_test(normalize("{hello }") == "{hello}", "Only closing space should normalize")

-- No spaces: unchanged
assert_test(normalize("{hello}") == "{hello}", "No spaces = no change")

-- Nested brackets
assert_test(normalize("{ items: [ a, b ] }") == "{items: [a, b]}", "Nested brackets normalize")

-- Multiple bracket types on one line
assert_test(normalize("( x ) and [ y ]") == "(x) and [y]", "Multiple bracket types normalize")

-- Interior spaces preserved
assert_test(normalize("{ a b c }") == "{a b c}", "Interior spaces preserved, only boundary spaces removed")

-- Empty brackets with space
assert_test(normalize("{ }") == "{}", "Empty brackets with space normalize to empty")

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_change_inside_brackets")
