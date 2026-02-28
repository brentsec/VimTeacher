-- tests/test_text_objects_mega_review.lua
-- Tests for the text objects mega review lesson module

local text_objects_mega_review = require("vimteacher.lessons.text_objects_mega_review")

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

print("test_text_objects_mega_review: running...")

-- Seed RNG for reproducibility in tests
math.randomseed(12345)

-- Test 1: Module has all required fields
assert_test(text_objects_mega_review.title ~= nil, "Missing title")
assert_test(type(text_objects_mega_review.description) == "table", "description must be table")
assert_test(type(text_objects_mega_review.hint_lines) == "table", "hint_lines must be table")
assert_test(type(text_objects_mega_review.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-specific fields
assert_test(
	text_objects_mega_review.type == "insert",
	"type must be 'insert', got " .. tostring(text_objects_mega_review.type)
)
assert_test(type(text_objects_mega_review.allowed_keys) == "table", "allowed_keys must be table")
assert_test(text_objects_mega_review.challenges_required ~= nil, "Missing challenges_required")

-- Verify allowed_keys contains exactly "c"
assert_test(
	#text_objects_mega_review.allowed_keys == 1,
	"allowed_keys must have 1 entry, got " .. #text_objects_mega_review.allowed_keys
)
assert_test(text_objects_mega_review.allowed_keys[1] == "c", "allowed_keys[1] must be 'c'")

-- Verify allowed_modify_keys contains d
assert_test(type(text_objects_mega_review.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(#text_objects_mega_review.allowed_modify_keys == 1, "allowed_modify_keys must have 1 entry")
assert_test(text_objects_mega_review.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")

-- Test 3: compute_optimal works
local opt1 = text_objects_mega_review.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 3, "Row 0,Col 0 to Row 3,Col 5 should be 3, got " .. opt1)

local opt2 = text_objects_mega_review.compute_optimal({ row = 2, col = 7 }, { row = 2, col = 7 })
assert_test(opt2 == 1, "Same position should be 1, got " .. opt2)

local opt3 = text_objects_mega_review.compute_optimal({ row = 2, col = 0 }, { row = 2, col = 10 })
assert_test(opt3 == 2, "Same row, col 0 to 10 should be 2, got " .. opt3)

-- Test 4: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_text_objects_mega_review")
local challenge = text_objects_mega_review.generate_challenge(buf, ns)

assert_test(challenge.snippet_lines ~= nil, "Missing snippet_lines")
assert_test(challenge.expected_lines ~= nil, "Missing expected_lines")
assert_test(challenge.target ~= nil, "Missing target")
assert_test(challenge.target.row ~= nil, "Missing target.row")
assert_test(challenge.target.col ~= nil, "Missing target.col")
assert_test(challenge.start_pos ~= nil, "Missing start_pos")
assert_test(challenge.key ~= nil, "Missing key")
assert_test(challenge.char ~= nil, "Missing char")

-- Test 5: snippet_lines and expected_lines differ
local lines_differ = false
for i = 1, #challenge.snippet_lines do
	if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
		lines_differ = true
		break
	end
end
assert_test(lines_differ, "snippet_lines and expected_lines must differ")

-- Test 6: Target is within snippet bounds
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(
	challenge.target.row < #challenge.snippet_lines,
	"target.row out of bounds: " .. challenge.target.row .. " >= " .. #challenge.snippet_lines
)

-- Test 7: Challenge pool has at least 15 challenges covering all categories
local challenges = text_objects_mega_review._get_challenges()
assert_test(#challenges >= 15, "Must have at least 15 challenges, got " .. #challenges)

-- Count challenge types
local bracket_count = 0
local quote_count = 0
local word_count = 0
local paragraph_count = 0

for _, c in ipairs(challenges) do
	local k = c.key
	if k:match("^[dc][ia][%(%[{]") then
		bracket_count = bracket_count + 1
	elseif k:match("^[dc][ia][\"']") then
		quote_count = quote_count + 1
	elseif k:match("^[dc][ia]w") then
		word_count = word_count + 1
	elseif k:match("^[dc][ia]p") then
		paragraph_count = paragraph_count + 1
	end
end

assert_test(bracket_count >= 3, "Must have at least 3 bracket challenges, got " .. bracket_count)
assert_test(quote_count >= 3, "Must have at least 3 quote challenges, got " .. quote_count)
assert_test(word_count >= 3, "Must have at least 3 word challenges, got " .. word_count)
assert_test(paragraph_count >= 3, "Must have at least 3 paragraph challenges, got " .. paragraph_count)

-- Test 8: CRITICAL — Simulated edit correctness for ALL challenges
-- Helper: find enclosing bracket pair (simplified - no nesting)
local function find_bracket_pair(line, col, open_char, close_char)
	local open_pos = nil
	local close_pos = nil

	-- Find opening bracket before or at col (search backwards)
	for i = col, 0, -1 do
		if line:sub(i + 1, i + 1) == open_char then
			open_pos = i
			break
		end
	end

	if not open_pos then
		return nil, nil
	end

	-- Find closing bracket after open_pos (search forwards)
	for i = open_pos + 1, #line - 1 do
		if line:sub(i + 1, i + 1) == close_char then
			close_pos = i
			break
		end
	end

	return open_pos, close_pos
end

-- Helper: find word boundaries
local function find_word_bounds(line, col)
	-- Find start of word
	local start_pos = col
	while start_pos > 0 do
		local ch = line:sub(start_pos, start_pos)
		if not ch:match("[%w_]") then
			break
		end
		start_pos = start_pos - 1
	end
	if not line:sub(start_pos + 1, start_pos + 1):match("[%w_]") then
		start_pos = start_pos + 1
	end

	-- Find end of word
	local end_pos = col
	while end_pos < #line do
		local ch = line:sub(end_pos + 2, end_pos + 2)
		if not ch:match("[%w_]") then
			break
		end
		end_pos = end_pos + 1
	end

	return start_pos, end_pos
end

-- Helper: find paragraph bounds (1-indexed row)
local function find_paragraph_bounds(lines, row)
	local start_row = row
	local end_row = row

	-- Find start of paragraph (move backwards while lines have content)
	while start_row > 1 and lines[start_row - 1] and lines[start_row - 1]:match("%S") do
		start_row = start_row - 1
	end

	-- Find end of paragraph (move forwards while lines have content)
	while end_row < #lines and lines[end_row + 1] and lines[end_row + 1]:match("%S") do
		end_row = end_row + 1
	end

	return start_row, end_row
end

for idx, c in ipairs(challenges) do
	-- Validate required fields
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.char ~= nil, "Challenge " .. idx .. ": missing char")

	-- Verify target is within snippet bounds
	assert_test(
		c.target.row < #c.snippet_lines,
		"Challenge " .. idx .. ": target.row " .. c.target.row .. " >= " .. #c.snippet_lines
	)

	-- Simulate the edit
	local edited = vim.deepcopy(c.snippet_lines)
	local key = c.key
	local row = c.target.row
	local col = c.target.col

	if key:match("^di[%(%[{]") or key:match("^da[%(%[{]") or key:match("^ci[%(%[{]") or key:match("^ca[%(%[{]") then
		-- Bracket operations
		local line = edited[row + 1]
		local open_char, close_char = "(", ")"
		if key:match("%[") then
			open_char, close_char = "[", "]"
		elseif key:match("{") then
			open_char, close_char = "{", "}"
		end

		local open_pos, close_pos = find_bracket_pair(line, col, open_char, close_char)
		if open_pos and close_pos then
			if key:sub(1, 2) == "di" or key:sub(1, 2) == "ci" then
				-- delete inside
				edited[row + 1] = line:sub(1, open_pos + 1) .. line:sub(close_pos + 1)
			else
				-- delete around
				edited[row + 1] = line:sub(1, open_pos) .. line:sub(close_pos + 2)
			end

			-- For ci/ca, append the char
			if key:sub(1, 1) == "c" then
				local insert_pos = open_pos + 1
				if key:sub(1, 2) == "ca" then
					insert_pos = open_pos
				end
				edited[row + 1] = edited[row + 1]:sub(1, insert_pos) .. c.char .. edited[row + 1]:sub(insert_pos + 1)
			end
		end
	elseif key:match("^di[\"']") or key:match("^da[\"']") or key:match("^ci[\"']") or key:match("^ca[\"']") then
		-- Quote operations
		local line = edited[row + 1]
		local quote_char = key:sub(3, 3)

		-- Find enclosing quotes
		local first_quote = nil
		local second_quote = nil

		-- Search backwards for opening quote
		for i = col, 0, -1 do
			if line:sub(i + 1, i + 1) == quote_char then
				first_quote = i
				break
			end
		end

		-- Search forwards for closing quote
		if first_quote then
			for i = col + 1, #line - 1 do
				if line:sub(i + 1, i + 1) == quote_char then
					second_quote = i
					break
				end
			end
		end

		if first_quote and second_quote then
			if key:sub(1, 2) == "di" or key:sub(1, 2) == "ci" then
				-- delete inside
				edited[row + 1] = line:sub(1, first_quote + 1) .. line:sub(second_quote + 1)
			else
				-- delete around
				edited[row + 1] = line:sub(1, first_quote) .. line:sub(second_quote + 2)
			end

			-- For ci/ca, append the char
			if key:sub(1, 1) == "c" then
				local insert_pos = first_quote + 1
				if key:sub(1, 2) == "ca" then
					insert_pos = first_quote
				end
				edited[row + 1] = edited[row + 1]:sub(1, insert_pos) .. c.char .. edited[row + 1]:sub(insert_pos + 1)
			end
		end
	elseif key:match("^[dc][ia]w") then
		-- Word operations
		local line = edited[row + 1]
		local start_pos, end_pos = find_word_bounds(line, col)

		if key:sub(1, 2) == "di" or key:sub(1, 2) == "ci" then
			-- delete inner word
			edited[row + 1] = line:sub(1, start_pos) .. line:sub(end_pos + 2)
		else
			-- delete a word (include trailing space if present)
			local after_word = end_pos + 2
			if line:sub(after_word, after_word) == " " then
				after_word = after_word + 1
			end
			edited[row + 1] = line:sub(1, start_pos) .. line:sub(after_word)
		end

		-- For ci/ca, insert the char
		if key:sub(1, 1) == "c" then
			edited[row + 1] = edited[row + 1]:sub(1, start_pos) .. c.char .. edited[row + 1]:sub(start_pos + 1)
		end
	elseif key:match("^[dc][ia]p") then
		-- Paragraph operations (1-indexed for Lua arrays)
		local start_row, end_row = find_paragraph_bounds(edited, row + 1)

		-- Build new lines array
		local new_lines = {}

		-- Copy lines before paragraph
		for i = 1, start_row - 1 do
			table.insert(new_lines, edited[i])
		end

		-- For cip/cap, insert the replacement char
		if key:sub(1, 1) == "c" and c.char ~= "" then
			table.insert(new_lines, c.char)
		end

		-- Determine what comes after the paragraph
		local next_idx = end_row + 1

		-- For dap/cap (around), skip the trailing blank line
		if (key:sub(1, 2) == "da" or key:sub(1, 2) == "ca") and next_idx <= #edited and edited[next_idx] == "" then
			next_idx = next_idx + 1
		end

		-- Copy remaining lines
		for i = next_idx, #edited do
			table.insert(new_lines, edited[i])
		end

		edited = new_lines
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
		assert_test(
			edited[i] == c.expected_lines[i],
			"Challenge "
				.. idx
				.. " ("
				.. c.key
				.. ") line "
				.. i
				.. ": got '"
				.. (edited[i] or "nil")
				.. "' expected '"
				.. c.expected_lines[i]
				.. "'"
		)
	end
end

-- Test 9: Run 50 generations without crashes
for i = 1, 50 do
	local ch = text_objects_mega_review.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " returned nil snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " returned nil expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " returned nil target")
	assert_test(ch.start_pos ~= nil, "Generation " .. i .. " returned nil start_pos")
end

-- Cleanup
vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_text_objects_mega_review: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
