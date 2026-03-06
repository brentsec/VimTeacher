-- tests/test_quote_text_objects.lua
-- Tests for the quote text objects lesson module (di", da", ci", ca")

local quote_text_objects = require("vimteacher.lessons.quote_text_objects")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_quote_text_objects: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(quote_text_objects.title ~= nil, "Missing title")
assert_test(type(quote_text_objects.description) == "table", "description must be table")
assert_test(type(quote_text_objects.hint_lines) == "table", "hint_lines must be table")
assert_test(type(quote_text_objects.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(quote_text_objects.type == "insert", "type must be 'insert', got " .. tostring(quote_text_objects.type))
assert_test(type(quote_text_objects.allowed_keys) == "table", "allowed_keys must be table")
assert_test(quote_text_objects.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#quote_text_objects.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #quote_text_objects.allowed_keys
)
assert_test(quote_text_objects.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains d
assert_test(type(quote_text_objects.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#quote_text_objects.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(quote_text_objects.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works (Manhattan distance + 1 operation)
local opt1 = quote_text_objects.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 9, "Row 0,Col 0 to Row 3,Col 5 should be 9 (8 moves + 1 op), got " .. opt1)

local opt2 = quote_text_objects.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 1, "Same position should be 1 (0 moves + 1 op), got " .. opt2)

local opt3 = quote_text_objects.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 11, "Same row, col 0 to 10 should be 11 (10 moves + 1 op), got " .. opt3)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_quote_text_objects")
local challenge = quote_text_objects.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")

-- Validate key is one of the quote text object operations
local valid_keys = {
	['di"'] = true,
	['da"'] = true,
	['ci"'] = true,
	['ca"'] = true,
	["di'"] = true,
	["da'"] = true,
	["ci'"] = true,
	["ca'"] = true,
}
assert_test(
	valid_keys[challenge.key] == true,
	"key must be a quote text object operation, got '" .. tostring(challenge.key) .. "'"
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

-- Test 8: CRITICAL — Simulated edit correctness for ALL challenges
-- di": find enclosing quotes, delete contents between them (keep quotes)
-- da": find quotes, delete quotes AND contents
-- ci": find quotes, replace contents with char (keep quotes)
-- ca": find quotes, replace quotes+contents with char
local challenges = quote_text_objects._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")

	local key_valid = valid_keys[c.key] == true
	assert_test(
		key_valid,
		"Challenge " .. idx .. ": key must be a quote text object operation, got '" .. tostring(c.key) .. "'"
	)

	-- Verify same line count (quote operations don't add/remove lines)
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

	-- Simulate the edit
	local edited = vim.deepcopy(c.snippet_lines)
	local line = edited[c.target.row + 1]
	local col = c.target.col

	-- Determine quote character from the key
	local quote_char = c.key:find('"') and '"' or "'"

	-- Find enclosing quotes around target.col
	local quote_start = nil
	local quote_end = nil

	-- Search backward for opening quote
	for i = col, 0, -1 do
		if line:sub(i + 1, i + 1) == quote_char then
			quote_start = i
			break
		end
	end

	-- Search forward for closing quote
	for i = col + 1, #line - 1 do
		if line:sub(i + 1, i + 1) == quote_char then
			quote_end = i
			break
		end
	end

	assert_test(
		quote_start ~= nil and quote_end ~= nil,
		"Challenge " .. idx .. ": could not find enclosing " .. quote_char .. " quotes around col " .. col
	)

	if quote_start and quote_end then
		if c.key:sub(1, 2) == "di" then
			-- di": delete inside quotes (keep quotes)
			edited[c.target.row + 1] = line:sub(1, quote_start + 1) .. line:sub(quote_end + 1)
		elseif c.key:sub(1, 2) == "da" then
			-- da": delete around quotes (quotes + contents)
			edited[c.target.row + 1] = line:sub(1, quote_start) .. line:sub(quote_end + 2)
		elseif c.key:sub(1, 2) == "ci" then
			-- ci": change inside quotes (replace contents with char, keep quotes)
			edited[c.target.row + 1] = line:sub(1, quote_start + 1) .. c.char .. line:sub(quote_end + 1)
		elseif c.key:sub(1, 2) == "ca" then
			-- ca": change around quotes (replace quotes + contents with char)
			edited[c.target.row + 1] = line:sub(1, quote_start) .. c.char .. line:sub(quote_end + 2)
		end
	end

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

-- Test 9: Run 50 generations without crashes
for i = 1, 50 do
	local ch = quote_text_objects.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_quote_text_objects")
