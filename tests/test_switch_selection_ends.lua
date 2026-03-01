-- tests/test_switch_selection_ends.lua
-- Tests for the switch selection ends lesson module

local switch_selection_ends = require("vimteacher.lessons.switch_selection_ends")

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

print("test_switch_selection_ends: running...")
math.randomseed(12345)

-- Test 1: Required lesson fields
assert_test(switch_selection_ends.title ~= nil, "Missing title")
assert_test(type(switch_selection_ends.description) == "table", "description must be table")
assert_test(type(switch_selection_ends.hint_lines) == "table", "hint_lines must be table")
assert_test(type(switch_selection_ends.generate_challenge) == "function", "generate_challenge must be function")

-- Test 2: Insert-lesson fields
assert_test(switch_selection_ends.type == "insert", "type must be 'insert'")
assert_test(switch_selection_ends.challenges_required == 10, "challenges_required must be 10")
assert_test(type(switch_selection_ends.allowed_keys) == "table", "allowed_keys must be table")
assert_test(type(switch_selection_ends.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(type(switch_selection_ends.allowed_visual_keys) == "table", "allowed_visual_keys must be table")
assert_test(switch_selection_ends.allowed_keys[1] == "o", "allowed_keys[1] must be 'o'")
assert_test(switch_selection_ends.allowed_modify_keys[1] == "d", "allowed_modify_keys[1] must be 'd'")
assert_test(switch_selection_ends.allowed_visual_keys[1] == "v", "allowed_visual_keys[1] must be 'v'")
assert_test(type(switch_selection_ends.compute_optimal) == "function", "compute_optimal must be function")

-- Test 3: Description/hints mention o
local desc_text = table.concat(switch_selection_ends.description, " ")
local hint_text = table.concat(switch_selection_ends.hint_lines, " ")
assert_test(desc_text:find("'o'") ~= nil or desc_text:find(" o ") ~= nil, "Description should mention o key")
assert_test(hint_text:find("%[o%]") ~= nil, "Hints should include [o]")

-- Test 4: compute_optimal baseline
local opt1 = switch_selection_ends.compute_optimal({ row = 0, col = 0 }, { row = 3, col = 5 })
assert_test(opt1 == 8, "Expected Manhattan fallback of 8, got " .. tostring(opt1))

-- Test 5: generate_challenge structure
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_switch_selection_ends")
local challenge = switch_selection_ends.generate_challenge(buf, ns)

assert_test(type(challenge) == "table", "challenge must be table")
assert_test(type(challenge.snippet_lines) == "table", "snippet_lines must be table")
assert_test(type(challenge.expected_lines) == "table", "expected_lines must be table")
assert_test(type(challenge.target) == "table", "target must be table")
assert_test(type(challenge.select_end) == "table", "select_end must be table")
assert_test(type(challenge.start_pos) == "table", "start_pos must be table")
assert_test(type(challenge.key) == "string", "key must be string")
assert_test(challenge.key:match("^v.*d$") ~= nil, "key must match visual-delete pattern")

-- Test 6: snippet and expected lengths match, but content differs
assert_test(
	#challenge.snippet_lines == #challenge.expected_lines,
	"snippet_lines and expected_lines must have same number of lines"
)
local differs = false
for i = 1, #challenge.snippet_lines do
	if challenge.snippet_lines[i] ~= challenge.expected_lines[i] then
		differs = true
		break
	end
end
assert_test(differs, "snippet_lines and expected_lines must differ")

-- Test 7: Validate all raw challenges and simulated delete behavior
local all = switch_selection_ends._get_challenges()
assert_test(#all >= 10, "Must have at least 10 raw challenges")

for idx, c in ipairs(all) do
	assert_test(c.target ~= nil, "Challenge " .. idx .. ": missing target")
	assert_test(c.select_end ~= nil, "Challenge " .. idx .. ": missing select_end")
	assert_test(c.start_pos ~= nil, "Challenge " .. idx .. ": missing start_pos")
	assert_test(c.key ~= nil, "Challenge " .. idx .. ": missing key")
	assert_test(c.key:match("^v.*d$") ~= nil, "Challenge " .. idx .. ": key must match visual-delete pattern")

	assert_test(
		#c.snippet_lines == #c.expected_lines,
		"Challenge " .. idx .. ": line count mismatch between snippet and expected"
	)
	assert_test(
		c.target.row >= 0 and c.target.row < #c.snippet_lines,
		"Challenge " .. idx .. ": target.row out of bounds"
	)
	assert_test(
		c.select_end.row == c.target.row,
		"Challenge " .. idx .. ": select_end.row must equal target.row (single-line selection)"
	)

	local sline = c.snippet_lines[c.target.row + 1]
	assert_test(c.target.col >= 0 and c.target.col < #sline, "Challenge " .. idx .. ": target.col out of bounds")
	assert_test(
		c.select_end.col >= 0 and c.select_end.col < #sline,
		"Challenge " .. idx .. ": select_end.col out of bounds"
	)

	-- Simulate visual deletion over the highlighted span.
	local start_col = math.min(c.target.col, c.select_end.col)
	local end_col = math.max(c.target.col, c.select_end.col)
	local edited = vim.deepcopy(c.snippet_lines)
	edited[c.target.row + 1] = sline:sub(1, start_col) .. sline:sub(end_col + 2)

	for i = 1, #c.expected_lines do
		assert_test(
			edited[i] == c.expected_lines[i],
			"Challenge "
				.. idx
				.. " line "
				.. i
				.. ": got '"
				.. edited[i]
				.. "', expected '"
				.. c.expected_lines[i]
				.. "'"
		)
	end
end

-- Test 8: Generation stability
for i = 1, 50 do
	local ch = switch_selection_ends.generate_challenge(buf, ns)
	assert_test(ch.snippet_lines ~= nil, "Generation " .. i .. " missing snippet_lines")
	assert_test(ch.expected_lines ~= nil, "Generation " .. i .. " missing expected_lines")
	assert_test(ch.target ~= nil, "Generation " .. i .. " missing target")
	assert_test(ch.select_end ~= nil, "Generation " .. i .. " missing select_end")
	assert_test(ch.key:match("^v.*d$") ~= nil, "Generation " .. i .. " key must be visual delete pattern")
end

vim.api.nvim_buf_delete(buf, { force = true })

print(
	string.format(
		"test_switch_selection_ends: %d passed, %d failed (total: %d assertions)",
		pass_count,
		fail_count,
		pass_count + fail_count
	)
)

if fail_count > 0 then
	vim.cmd("cquit! 1")
end
