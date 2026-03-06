-- tests/test_repeat_power.lua
-- Tests for two-phase repeat-power lesson behavior.

local repeat_power = require("vimteacher.lessons.repeat_power")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

local function apply_x_n(line, col, n)
	local out = line
	for _ = 1, n do
		if col >= #out then
			break
		end
		out = out:sub(1, col) .. out:sub(col + 2)
	end
	return out
end

local function parse_delete_count(key)
	if key == "x" then
		return 1
	end
	local n = tonumber((key or ""):match("^(%d+)x$"))
	return n
end

print("test_repeat_power: running...")

math.randomseed(12345)

-- Test 1: Module contract
assert_test(repeat_power.title ~= nil, "Missing title")
assert_test(type(repeat_power.description) == "table", "description must be table")
assert_test(type(repeat_power.hint_lines) == "table", "hint_lines must be table")
assert_test(type(repeat_power.generate_challenge) == "function", "generate_challenge must be function")
assert_test(repeat_power.type == "insert", "type must be 'insert'")
assert_test(type(repeat_power.allowed_keys) == "table", "allowed_keys must be table")
assert_test(type(repeat_power.allowed_modify_keys) == "table", "allowed_modify_keys must be table")
assert_test(type(repeat_power.allowed_nav_keys) == "table", "allowed_nav_keys must be table")
assert_test(repeat_power.challenges_required == 10, "challenges_required should be 10")

-- Test 2: allowed modify keys
local modify_set = {}
for _, key in ipairs(repeat_power.allowed_modify_keys) do
	modify_set[key] = true
end
assert_test(modify_set["x"] == true, "allowed_modify_keys must contain 'x'")
assert_test(modify_set["."] == true, "allowed_modify_keys must contain '.'")

local nav_set = {}
for _, key in ipairs(repeat_power.allowed_nav_keys) do
	nav_set[key] = true
end
assert_test(nav_set["3"] == true, "allowed_nav_keys must contain '3' for count prefixes")

-- Test 3: compute_optimal baseline + phased path sum
local base = repeat_power.compute_optimal({ row = 0, col = 0 }, { row = 2, col = 5 })
assert_test(base == 7, "Expected Manhattan 7 for non-phased baseline, got " .. tostring(base))

do
	local c = repeat_power._get_challenges()[1]
	local start = c.start_pos
	local p1 = c.phases[1].target
	local p2 = c.phases[2].target
	local expected = repeat_power._compute_nav_optimal(c.snippet_lines, start, p1)
		+ repeat_power._compute_nav_optimal(c.phases[1].expected_lines, p1, p2)
	local got = repeat_power.compute_optimal(start, c.target, c)
	assert_test(got == expected, "Phased optimal mismatch: expected " .. expected .. " got " .. got)
	local manhattan = math.abs(start.row - p1.row)
		+ math.abs(start.col - p1.col)
		+ math.abs(p1.row - p2.row)
		+ math.abs(p1.col - p2.col)
	assert_test(got <= manhattan, "Phased optimal should not exceed Manhattan baseline")
end

-- Test 4: static challenge semantics + two-phase simulation
local challenges = repeat_power._get_challenges()
assert_test(#challenges >= 10, "Must have at least 10 challenges, got " .. #challenges)

for idx, c in ipairs(challenges) do
	assert_test(c.snippet_lines ~= nil, "Challenge " .. idx .. ": missing snippet_lines")
	assert_test(c.expected_lines ~= nil, "Challenge " .. idx .. ": missing expected_lines")
	assert_test(c.phases ~= nil, "Challenge " .. idx .. ": missing phases")
	assert_test(#(c.phases or {}) == 2, "Challenge " .. idx .. ": must have exactly 2 phases")

	local p1 = c.phases[1]
	local p2 = c.phases[2]
	assert_test(p1.key == "x" or p1.key:match("^%d+x$"), "Challenge " .. idx .. ": phase1 key must be x or Nx")
	assert_test(p2.key == ".", "Challenge " .. idx .. ": phase2 key must be '.'")
	assert_test(
		c.target.row == p1.target.row and c.target.col == p1.target.col,
		"Challenge " .. idx .. ": target must equal phase1 target"
	)
	assert_test(c.key == p1.key, "Challenge " .. idx .. ": challenge.key must equal phase1 key")

	local n = parse_delete_count(p1.key)
	assert_test(n ~= nil and n >= 1, "Challenge " .. idx .. ": invalid phase1 delete key " .. tostring(p1.key))

	assert_test(
		#c.snippet_lines == #p1.expected_lines,
		"Challenge " .. idx .. ": phase1 expected line count must match snippet line count"
	)
	assert_test(
		#p1.expected_lines == #p2.expected_lines,
		"Challenge " .. idx .. ": phase2 expected line count must match phase1 expected line count"
	)
	assert_test(
		#p2.expected_lines == #c.expected_lines,
		"Challenge " .. idx .. ": challenge expected lines must match phase2 expected lines"
	)

	local row1 = p1.target.row
	local row2 = p2.target.row
	local line1 = c.snippet_lines[row1 + 1] or ""
	assert_test(p1.target.col >= 0 and p1.target.col < #line1, "Challenge " .. idx .. ": phase1 target out of bounds")

	local after1 = vim.deepcopy(c.snippet_lines)
	after1[row1 + 1] = apply_x_n(after1[row1 + 1], p1.target.col, n)
	for i = 1, #p1.expected_lines do
		assert_test(
			after1[i] == p1.expected_lines[i],
			"Challenge "
				.. idx
				.. " phase1 line "
				.. i
				.. ": got '"
				.. after1[i]
				.. "' expected '"
				.. p1.expected_lines[i]
				.. "'"
		)
	end

	local line2 = after1[row2 + 1] or ""
	assert_test(p2.target.col >= 0 and p2.target.col < #line2, "Challenge " .. idx .. ": phase2 target out of bounds")

	local after2 = vim.deepcopy(after1)
	after2[row2 + 1] = apply_x_n(after2[row2 + 1], p2.target.col, n)
	for i = 1, #p2.expected_lines do
		assert_test(
			after2[i] == p2.expected_lines[i],
			"Challenge "
				.. idx
				.. " phase2 line "
				.. i
				.. ": got '"
				.. after2[i]
				.. "' expected '"
				.. p2.expected_lines[i]
				.. "'"
		)
		assert_test(
			after2[i] == c.expected_lines[i],
			"Challenge "
				.. idx
				.. " final line "
				.. i
				.. ": got '"
				.. after2[i]
				.. "' expected '"
				.. c.expected_lines[i]
				.. "'"
		)
	end
end

-- Test 5: generated challenge shape stability
local buf = vim.api.nvim_create_buf(false, true)
local ns = vim.api.nvim_create_namespace("test_repeat_power")
for i = 1, 50 do
	local c = repeat_power.generate_challenge(buf, ns)
	assert_test(c.snippet_lines ~= nil, "Generation " .. i .. ": nil snippet_lines")
	assert_test(c.expected_lines ~= nil, "Generation " .. i .. ": nil expected_lines")
	assert_test(c.target ~= nil, "Generation " .. i .. ": nil target")
	assert_test(c.phases ~= nil and #c.phases == 2, "Generation " .. i .. ": phases must be size 2")
	local key1 = c.phases[1].key
	assert_test(key1 == "x" or key1:match("^%d+x$"), "Generation " .. i .. ": invalid phase1 key")
	assert_test(c.phases[2].key == ".", "Generation " .. i .. ": phase2 key must be '.'")
end
vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_repeat_power")
