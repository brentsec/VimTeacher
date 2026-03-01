-- tests/test_search_replace.lua
-- Tests for the search/replace lesson module

local search_replace = require("vimteacher.lessons.search_replace")

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

local function lines_equal(a, b)
	if #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

print("test_search_replace: running...")
math.randomseed(12345)

-- Test 1: Required lesson fields
assert_test(search_replace.title ~= nil, "Missing title")
assert_test(type(search_replace.description) == "table", "description must be table")
assert_test(type(search_replace.hint_lines) == "table", "hint_lines must be table")
assert_test(type(search_replace.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(search_replace.compute_optimal) == "function", "compute_optimal must be function")

-- Test 2: Insert lesson shape and key permissions
assert_test(search_replace.type == "insert", "type must be 'insert'")
assert_test(search_replace.challenges_required == 10, "challenges_required must be 10")
assert_test(type(search_replace.allowed_keys) == "table", "allowed_keys must be table")
assert_test(type(search_replace.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(type(search_replace.allowed_visual_keys) == "table", "allowed_visual_keys must be table")
assert_test(#search_replace.allowed_keys >= 5, "allowed_keys should include insert-entry keys")
assert_test(#search_replace.allowed_modify_keys >= 5, "allowed_modify_keys should keep normal edits unblocked")
assert_test(#search_replace.allowed_visual_keys == 3, "allowed_visual_keys should include v/V/<C-v>")

-- Test 3: Description/hints mention substitution commands
local desc_text = table.concat(search_replace.description, " ")
local hint_text = table.concat(search_replace.hint_lines, " ")
assert_test(desc_text:find(":s", 1, true) ~= nil, "Description should mention :s")
assert_test(desc_text:find(":%s", 1, true) ~= nil, "Description should mention :%s")
assert_test(hint_text:find(":s", 1, true) ~= nil, "Hints should mention :s")
assert_test(hint_text:find(":%s", 1, true) ~= nil, "Hints should mention :%s")

-- Test 4: compute_optimal baseline fallback
local opt = search_replace.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt == 8, "Fallback compute_optimal should be Manhattan (8), got " .. tostring(opt))

-- Test 5: generate_challenge returns valid structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_search_replace")
local challenge = search_replace.generate_challenge(buf, ns)

assert_test(type(challenge) == "table", "generate_challenge must return a table")
assert_test(type(challenge.snippet_lines) == "table", "challenge.snippet_lines must be table")
assert_test(type(challenge.expected_lines) == "table", "challenge.expected_lines must be table")
assert_test(type(challenge.target) == "table", "challenge.target must be table")
assert_test(type(challenge.start_pos) == "table", "challenge.start_pos must be table")
assert_test(type(challenge.goal_text) == "string", "challenge.goal_text must be string")
assert_test(type(challenge.target_end_col) == "number", "challenge.target_end_col must be number")

-- Test 6: target + highlight bounds are valid
assert_test(challenge.target.row >= 0, "target.row must be >= 0")
assert_test(challenge.target.row < #challenge.snippet_lines, "target.row out of bounds")
local tline = challenge.snippet_lines[challenge.target.row + 1]
assert_test(type(tline) == "string", "target line must exist")
assert_test(challenge.target.col >= 0, "target.col must be >= 0")
assert_test(challenge.target.col < #tline, "target.col out of bounds")
assert_test(challenge.target_end_col > challenge.target.col, "target_end_col must be > target.col")
assert_test(challenge.target_end_col <= #tline, "target_end_col out of bounds")

-- Test 7: all raw challenges are internally consistent and semantic
local all = search_replace._get_challenges()
assert_test(#all >= 10, "Must define at least 10 challenges")

for idx, c in ipairs(all) do
	assert_test(type(c.snippet_lines) == "table", "Challenge " .. idx .. ": snippet_lines must be table")
	assert_test(type(c.expected_lines) == "table", "Challenge " .. idx .. ": expected_lines must be table")
	assert_test(type(c.target) == "table", "Challenge " .. idx .. ": target must be table")
	assert_test(type(c.start_pos) == "table", "Challenge " .. idx .. ": start_pos must be table")
	assert_test(type(c.goal_text) == "string", "Challenge " .. idx .. ": goal_text must be string")
	local has_subst = c.goal_text:find(":s", 1, true) ~= nil
		or c.goal_text:find(":%s", 1, true) ~= nil
		or c.goal_text:find("s/", 1, true) ~= nil
	assert_test(has_subst, "Challenge " .. idx .. ": goal_text should mention substitution syntax")

	assert_test(
		#c.snippet_lines == #c.expected_lines,
		"Challenge " .. idx .. ": expected_lines should keep line count stable"
	)
	assert_test(c.target.row >= 0 and c.target.row < #c.snippet_lines, "Challenge " .. idx .. ": target.row invalid")
	local sline = c.snippet_lines[c.target.row + 1]
	assert_test(c.target.col >= 0 and c.target.col < #sline, "Challenge " .. idx .. ": target.col invalid")
	assert_test(
		c.target_end_col > c.target.col and c.target_end_col <= #sline,
		"Challenge " .. idx .. ": target_end_col invalid"
	)
	local token = sline:sub(c.target.col + 1, c.target_end_col)
	assert_test(#token > 0, "Challenge " .. idx .. ": highlight token cannot be empty")

	local differs = false
	for i = 1, #c.snippet_lines do
		if c.snippet_lines[i] ~= c.expected_lines[i] then
			differs = true
			break
		end
	end
	assert_test(differs, "Challenge " .. idx .. ": snippet and expected must differ")
	assert_test(
		c.snippet_lines[c.target.row + 1] ~= c.expected_lines[c.target.row + 1],
		"Challenge " .. idx .. ": target row must be edited by substitution"
	)
end

-- Test 8: generation stability
for i = 1, 60 do
	local ch = search_replace.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. ": missing snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. ": missing expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. ": missing target")
	assert_test(ch.goal_text ~= nil, "Generation " .. i .. ": missing goal_text")
	assert_test(ch.target_end_col ~= nil, "Generation " .. i .. ": missing target_end_col")
end

-- Test 9: range challenge command works exactly from the highlighted target line
local range_challenge = nil
for _, c in ipairs(all) do
	if c.goal_text:find(":.,+1s/draft/ready/g", 1, true) then
		range_challenge = c
		break
	end
end

assert_test(range_challenge ~= nil, "Range challenge with :.,+1s/draft/ready/g must exist")
if range_challenge then
	local cur_buf = vim.api.nvim_get_current_buf()
	local run_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_current_buf(run_buf)
	vim.api.nvim_buf_set_lines(run_buf, 0, -1, false, vim.deepcopy(range_challenge.snippet_lines))
	vim.api.nvim_win_set_cursor(0, { range_challenge.target.row + 1, range_challenge.target.col })

	local ok = pcall(vim.cmd, [[:.,+1s/draft/ready/g]])
	assert_test(ok, "Range challenge command should execute without Ex errors")

	local got = vim.api.nvim_buf_get_lines(run_buf, 0, -1, false)
	assert_test(
		lines_equal(got, range_challenge.expected_lines),
		"Range challenge command should match expected_lines exactly"
	)

	vim.api.nvim_set_current_buf(cur_buf)
	vim.api.nvim_buf_delete(run_buf, { force = true })
end

vim.api.nvim_buf_delete(buf, { force = true })

print(string.format("test_search_replace: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
