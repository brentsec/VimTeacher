-- tests/test_paragraph_text_objects.lua
-- Tests for the paragraph text objects lesson module (dip, dap, cip, cap)

local paragraph_text_objects = require("vimteacher.lessons.paragraph_text_objects")

local pass_count = 0
local fail_count = 0

local function assert_test(condition, msg)
	if condition then
		pass_count = pass_count + 1
	else
		fail_count = fail_count + 1
		print("  FAIL: " .. msg)
	end
end

print("test_paragraph_text_objects: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(paragraph_text_objects.title ~= nil, "Missing title")
assert_test(type(paragraph_text_objects.description) == "table", "description must be table")
assert_test(type(paragraph_text_objects.hint_lines) == "table", "hint_lines must be table")
assert_test(type(paragraph_text_objects.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(
	paragraph_text_objects.type == "insert",
	"type must be 'insert', got " .. tostring(paragraph_text_objects.type)
)
assert_test(type(paragraph_text_objects.allowed_keys) == "table", "allowed_keys must be table")
assert_test(paragraph_text_objects.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#paragraph_text_objects.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #paragraph_text_objects.allowed_keys
)
assert_test(paragraph_text_objects.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains d
assert_test(type(paragraph_text_objects.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#paragraph_text_objects.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(paragraph_text_objects.allowed_modify_keys[1] == "d", "allowed_modify_keys must contain 'd'")

-- Test 3: compute_optimal works (navigate to target + 1 operation)
local opt1 = paragraph_text_objects.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 0 })
assert_test(opt1 == 2, "Row 0,Col 0 to Row 3,Col 0 should be 2 (1 move + 1 op), got " .. opt1)

local opt2 = paragraph_text_objects.compute_optimal({ row = 2, col = 5 }, { row = 2, col = 5 })
assert_test(opt2 == 1, "Same position should be 1 (0 moves + 1 op), got " .. opt2)

local opt3 = paragraph_text_objects.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 2, "Same row, col 0 to 10 should be 2 (1 move + 1 op), got " .. opt3)

local opt4 = paragraph_text_objects.compute_optimal({ row = 0, col = 5 }, { row = 3, col = 0 })
assert_test(opt4 == 3, "Row 0,Col 5 to Row 3,Col 0 should be 3 (2 moves + 1 op), got " .. opt4)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_paragraph_text_objects")
local challenge = paragraph_text_objects.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")

-- Test 5: Snippets have blank-line-separated paragraph structure
local has_blank_line = false
for i = 1, #challenge.snippet_lines do
	if challenge.snippet_lines[i] == "" then
		has_blank_line = true
		break
	end
end
assert_test(has_blank_line, "Snippets must have blank lines separating paragraphs")

-- Test 6: Validate key format
assert_test(
	challenge.key == "dip" or challenge.key == "dap" or challenge.key == "cip" or challenge.key == "cap",
	"key must be 'dip', 'dap', 'cip', or 'cap', got '" .. tostring(challenge.key) .. "'"
)

-- Test 7: CRITICAL — Simulated edit correctness for ALL challenges
-- dip: deletes all non-blank lines in the paragraph block around target
-- dap: deletes paragraph block + trailing blank line
-- cip: deletes paragraph block (like dip) + replacement text
-- cap: deletes paragraph block + blank line + replacement text
local challenges = paragraph_text_objects._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

-- Helper function to find paragraph boundaries
local function find_paragraph_bounds(lines, target_row)
	local start_row = target_row
	local end_row = target_row

	-- Find start of paragraph (first non-blank line going backwards)
	while start_row > 0 and lines[start_row] ~= "" do
		start_row = start_row - 1
	end
	if lines[start_row] == "" then
		start_row = start_row + 1
	end

	-- Find end of paragraph (last non-blank line going forwards)
	while end_row <= #lines and lines[end_row] ~= "" do
		end_row = end_row + 1
	end
	end_row = end_row - 1

	return start_row, end_row
end

for idx, c in ipairs(challenges) do
	-- Validate required fields on each raw challenge
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(
		c.key == "dip" or c.key == "dap" or c.key == "cip" or c.key == "cap",
		"Challenge " .. idx .. ": key must be 'dip', 'dap', 'cip', or 'cap', got '" .. tostring(c.key) .. "'"
	)

	-- Verify target is within snippet bounds
	assert_test(
		c.target.row < #c.snippet_lines,
		"Challenge " .. idx .. ": target.row " .. c.target.row .. " >= " .. #c.snippet_lines
	)

	-- Simulate the edit
	local edited = {}
	local snippet = vim.deepcopy(c.snippet_lines)

	-- Find paragraph boundaries (1-indexed for Lua)
	local start_row, end_row = find_paragraph_bounds(snippet, c.target.row + 1)

	if c.key == "dip" then
		-- Delete inner paragraph: remove all non-blank lines in the block
		for i = 1, #snippet do
			if i < start_row or i > end_row then
				table.insert(edited, snippet[i])
			end
		end
	elseif c.key == "dap" then
		-- Delete a paragraph: remove block + trailing blank line
		for i = 1, #snippet do
			if i < start_row or i > end_row + 1 then
				table.insert(edited, snippet[i])
			end
		end
	elseif c.key == "cip" then
		-- Change inner paragraph: delete block, insert replacement
		assert_test(c.char ~= nil, "Challenge " .. idx .. ": cip requires char field")
		for i = 1, #snippet do
			if i < start_row then
				table.insert(edited, snippet[i])
			elseif i == start_row then
				table.insert(edited, c.char)
			elseif i > end_row then
				table.insert(edited, snippet[i])
			end
		end
	elseif c.key == "cap" then
		-- Change a paragraph: delete block + blank line, insert replacement
		assert_test(c.char ~= nil, "Challenge " .. idx .. ": cap requires char field")
		for i = 1, #snippet do
			if i < start_row then
				table.insert(edited, snippet[i])
			elseif i == start_row then
				table.insert(edited, c.char)
			elseif i > end_row + 1 then
				table.insert(edited, snippet[i])
			end
		end
	end

	-- Compare edited snippet to expected_lines
	assert_test(
		#edited == #c.expected_lines,
		"Challenge "
			.. idx
			.. " ("
			.. c.key
			.. "): edited line count "
			.. #edited
			.. " != expected "
			.. #c.expected_lines
	)
	for i = 1, #c.expected_lines do
		if edited[i] ~= c.expected_lines[i] then
			assert_test(
				false,
				"Challenge "
					.. idx
					.. " ("
					.. c.key
					.. ") line "
					.. i
					.. ":\n"
					.. "  got:      '"
					.. (edited[i] or "nil")
					.. "'\n"
					.. "  expected: '"
					.. c.expected_lines[i]
					.. "'"
			)
		else
			pass_count = pass_count + 1
		end
	end
end

-- Test 8: Verify line count changes for dip/dap
local dip_found = false
local dap_found = false
for idx, c in ipairs(challenges) do
	if c.key == "dip" then
		dip_found = true
		assert_test(
			#c.expected_lines < #c.snippet_lines,
			"Challenge "
				.. idx
				.. " (dip): expected_lines ("
				.. #c.expected_lines
				.. ") must be < snippet_lines ("
				.. #c.snippet_lines
				.. ")"
		)
	elseif c.key == "dap" then
		dap_found = true
		assert_test(
			#c.expected_lines < #c.snippet_lines,
			"Challenge "
				.. idx
				.. " (dap): expected_lines ("
				.. #c.expected_lines
				.. ") must be < snippet_lines ("
				.. #c.snippet_lines
				.. ")"
		)
	end
end
assert_test(dip_found, "Must have at least one dip challenge")
assert_test(dap_found, "Must have at least one dap challenge")

-- Test 9: Run 50 generations without crashes
for i = 1, 50 do
	local ch = paragraph_text_objects.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_paragraph_text_objects: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
