-- tests/test_macro_repetition.lua
-- Tests for the macro repetition lesson module.

local macro = require("vimteacher.lessons.macro_repetition")
local optimal = require("vimteacher.optimal")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

local function delete_one(line, col)
	if col < 0 or col >= #line then
		return line
	end
	return line:sub(1, col) .. line:sub(col + 2)
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

print("test_macro_repetition: running...")
math.randomseed(12345)

-- Test 1: Module contract
assert_test(macro.title ~= nil, "Missing title")
assert_test(type(macro.description) == "table", "description must be table")
assert_test(type(macro.hint_lines) == "table", "hint_lines must be table")
assert_test(type(macro.generate_challenge) == "function", "generate_challenge must be function")
assert_test(type(macro.compute_optimal) == "function", "compute_optimal must be function")
assert_test(macro.type == "insert", "type must be 'insert'")
assert_test(macro.challenges_required == 10, "challenges_required must be 10")
assert_test(type(macro.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(type(macro.allowed_visual_keys) == "table", "allowed_visual_keys must be table")
assert_test(macro.play_menu_key == "m", "macro lesson should move menu off q to free macro recording")

local desc_text = table.concat(macro.description, " ")
assert_test(desc_text:find("qa", 1, true) ~= nil, "Description should mention qa")
assert_test(desc_text:find("@a", 1, true) ~= nil, "Description should mention @a")
assert_test(desc_text:find("@@", 1, true) ~= nil, "Description should mention @@")
assert_test(desc_text:find("10@a", 1, true) ~= nil, "Description should mention 10@a")

-- Test 2: compute_optimal baseline fallback before generation
local base = macro.compute_optimal({ row = 0, col = 0 }, { row = 2, col = 5 })
assert_test(base == 7, "Fallback compute_optimal should be Manhattan (7), got " .. tostring(base))

-- Test 3: static challenge semantics
local challenges = macro._get_challenges()
assert_test(#challenges >= 10, "Must define at least 10 challenges")

local saw_double_at = false
local saw_counted = false
local saw_ten_count = false

for idx, c in ipairs(challenges) do
	assert_test(type(c.snippet_lines) == "table", "Challenge " .. idx .. ": snippet_lines must be table")
	assert_test(type(c.expected_lines) == "table", "Challenge " .. idx .. ": expected_lines must be table")
	assert_test(type(c.target) == "table", "Challenge " .. idx .. ": target must be table")
	assert_test(type(c.start_pos) == "table", "Challenge " .. idx .. ": start_pos must be table")
	assert_test(type(c.goal_text) == "string", "Challenge " .. idx .. ": goal_text must be string")
	assert_test(type(c.phases) == "table", "Challenge " .. idx .. ": phases must be table")
	assert_test(type(c._macro_targets) == "table", "Challenge " .. idx .. ": _macro_targets must be table")

	assert_test(#c.phases >= 2, "Challenge " .. idx .. ": must have at least 2 phases")
	assert_test(#c._macro_targets >= 2, "Challenge " .. idx .. ": must have at least 2 macro targets")
	assert_test(c.phases[1].goal_text:find("qa", 1, true) ~= nil, "Challenge " .. idx .. ": phase1 should mention qa")

	local p1 = c.phases[1]
	assert_test(
		p1.target.row == c.target.row and p1.target.col == c.target.col,
		"Challenge " .. idx .. ": challenge target should equal phase1 target"
	)
	assert_test(c.target_end_col == p1.target_end_col, "Challenge " .. idx .. ": target_end_col should match phase1")

	local running_lines = vim.deepcopy(c.snippet_lines)
	for phase_idx, p in ipairs(c.phases) do
		assert_test(type(p.target) == "table", "Challenge " .. idx .. " phase " .. phase_idx .. ": missing target")
		assert_test(
			type(p.goal_text) == "string",
			"Challenge " .. idx .. " phase " .. phase_idx .. ": missing goal_text"
		)
		assert_test(
			type(p.expected_lines) == "table",
			"Challenge " .. idx .. " phase " .. phase_idx .. ": expected_lines must be table"
		)
		assert_test(
			#p.expected_lines == #c.snippet_lines,
			"Challenge " .. idx .. " phase " .. phase_idx .. ": expected_lines line count mismatch"
		)

		local row = p.target.row
		local line = running_lines[row + 1] or ""
		assert_test(
			row >= 0 and row < #running_lines,
			"Challenge " .. idx .. " phase " .. phase_idx .. ": row out of bounds"
		)
		assert_test(
			p.target.col >= 0 and p.target.col < #line,
			"Challenge " .. idx .. " phase " .. phase_idx .. ": col out of bounds"
		)
		assert_test(
			p.target_end_col > p.target.col and p.target_end_col <= #line,
			"Challenge " .. idx .. " phase " .. phase_idx .. ": target_end_col invalid"
		)
		local token = line:sub(p.target.col + 1, p.target_end_col)
		assert_test(#token > 0, "Challenge " .. idx .. " phase " .. phase_idx .. ": token should not be empty")

		running_lines = vim.deepcopy(p.expected_lines)
	end

	local final_goal = c.phases[#c.phases].goal_text
	if final_goal:find("@@", 1, true) then
		saw_double_at = true
	end
	local count_txt = final_goal:match("(%d+)@a")
	if count_txt then
		local n = tonumber(count_txt)
		saw_counted = true
		assert_test(
			c.phases[1].goal_text:find("xj", 1, true) ~= nil,
			"Challenge " .. idx .. ": counted macro phase1 should teach xj movement"
		)
		assert_test(
			n == (#c._macro_targets - 1),
			"Challenge " .. idx .. ": counted repeat should match remaining targets"
		)
		local first_col = c._macro_targets[1].col
		for t_idx = 2, #c._macro_targets do
			assert_test(
				c._macro_targets[t_idx].col == first_col,
				"Challenge "
					.. idx
					.. ": counted macro targets should share column for xj replay (target "
					.. t_idx
					.. ")"
			)
		end
		if n == 10 then
			saw_ten_count = true
		end
	end

	local sim = vim.deepcopy(c.snippet_lines)
	for _, t in ipairs(c._macro_targets) do
		sim[t.row + 1] = delete_one(sim[t.row + 1], t.col)
	end
	assert_test(lines_equal(sim, c.expected_lines), "Challenge " .. idx .. ": macro target simulation mismatch")
	assert_test(
		lines_equal(c.phases[#c.phases].expected_lines, c.expected_lines),
		"Challenge " .. idx .. ": final phase must match challenge expected_lines"
	)
end

assert_test(saw_double_at, "At least one challenge should teach @@")
assert_test(saw_counted, "At least one challenge should teach counted @a")
assert_test(saw_ten_count, "At least one challenge should include 10@a")

-- Test 4: phased optimal path scoring
do
	local c = challenges[1]
	local pos = { row = c.start_pos.row, col = c.start_pos.col }
	local lines = c.snippet_lines
	local expected = 0
	for _, p in ipairs(c.phases) do
		expected = expected + optimal.nav_cost(lines, pos, p.target)
		lines = p.expected_lines
		pos = p.target
	end
	local got = macro.compute_optimal(c.start_pos, c.target, c)
	assert_test(got == expected, "Phased compute_optimal mismatch: expected " .. expected .. " got " .. tostring(got))
end

-- Test 5: generation stability
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_macro_repetition")
for i = 1, 60 do
	local c = macro.generate_challenge(buf, ns)
	assert_test(c.snippet_lines ~= nil, "Generation " .. i .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Generation " .. i .. ": missing expected_lines")
	assert_test(c.target ~= nil, "Generation " .. i .. ": missing target")
	assert_test(c.start_pos ~= nil, "Generation " .. i .. ": missing start_pos")
	assert_test(c.phases ~= nil and #c.phases >= 2, "Generation " .. i .. ": phases must be >= 2")
	assert_test(c._macro_targets ~= nil and #c._macro_targets >= 2, "Generation " .. i .. ": _macro_targets invalid")
end
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_macro_repetition")
