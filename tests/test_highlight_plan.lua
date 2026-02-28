-- tests/test_highlight_plan.lua
-- Semantic and visibility tests for challenge highlight planning.

local highlight_plan = require("vimteacher.highlight_plan")
local lessons = require("vimteacher.lessons")

local pass_count = 0
local fail_count = 0

local SINGLE_CHAR_KEYS = {
	i = true,
	a = true,
	I = true,
	A = true,
	x = true,
	r = true,
	cl = true,
}

local function assert_test(condition, msg)
	if condition then
		pass_count = pass_count + 1
	else
		fail_count = fail_count + 1
		print("  FAIL: " .. msg)
	end
end

local function effective_range(challenge, plan)
	if not challenge or not challenge.target then
		return nil
	end

	local target = challenge.target
	local line = challenge.snippet_lines and challenge.snippet_lines[target.row + 1] or ""
	local start_col = target.col
	local end_col = target.col + 1
	local full_line = false

	if plan then
		full_line = plan.full_line or false
		start_col = plan.start_col or start_col
		end_col = plan.end_col or (start_col + 1)
	end

	return {
		line = line,
		start_col = start_col,
		end_col = end_col,
		full_line = full_line,
	}
end

local function assert_visible(name, idx, challenge, plan)
	local range = effective_range(challenge, plan)
	assert_test(range ~= nil, string.format("%s #%d: missing range", name, idx))
	if not range then
		return
	end

	if range.full_line then
		assert_test(
			range.start_col == 0,
			string.format("%s #%d: full-line plan should start at col 0, got %d", name, idx, range.start_col)
		)
		return
	end

	assert_test(
		range.start_col >= 0 and range.start_col < #range.line,
		string.format(
			"%s #%d: start_col out of bounds (%d) for line len %d (%q)",
			name,
			idx,
			range.start_col,
			#range.line,
			range.line
		)
	)
	assert_test(
		range.end_col > range.start_col,
		string.format(
			"%s #%d: end_col must be > start_col (%d <= %d) for key %s",
			name,
			idx,
			range.end_col,
			range.start_col,
			tostring(challenge.key)
		)
	)
end

local function assert_semantics(name, idx, challenge, plan)
	local range = effective_range(challenge, plan)
	if not range then
		return
	end

	local key = challenge.key
	if key == "o" or key == "O" then
		assert_test(range.full_line, string.format("%s #%d: %s should highlight full line", name, idx, key))
	end

	if key == "dd" then
		assert_test(range.full_line, string.format("%s #%d: dd should highlight full line", name, idx))
	end

	if SINGLE_CHAR_KEYS[key] then
		assert_test(
			not range.full_line,
			string.format("%s #%d: %s should be single-char highlight, not full-line", name, idx, key)
		)
		assert_test(
			range.start_col == challenge.target.col,
			string.format(
				"%s #%d: %s should start at target col (%d), got %d",
				name,
				idx,
				key,
				challenge.target.col,
				range.start_col
			)
		)
		assert_test(
			range.end_col == challenge.target.col + 1,
			string.format(
				"%s #%d: %s should end at target+1 (%d), got %d",
				name,
				idx,
				key,
				challenge.target.col + 1,
				range.end_col
			)
		)
	end

	if (key == "vd" or key == "vc") and challenge.select_end and challenge.select_end.row == challenge.target.row then
		local expected_start = math.min(challenge.target.col, challenge.select_end.col)
		local expected_end = math.max(challenge.target.col, challenge.select_end.col) + 1
		assert_test(
			range.start_col == expected_start,
			string.format(
				"%s #%d: %s start should be min(target, select_end)=%d, got %d",
				name,
				idx,
				key,
				expected_start,
				range.start_col
			)
		)
		assert_test(
			range.end_col == expected_end,
			string.format(
				"%s #%d: %s end should be max(target, select_end)+1=%d, got %d",
				name,
				idx,
				key,
				expected_end,
				range.end_col
			)
		)
	end
end

print("test_highlight_plan: running...")

-- Targeted semantic checks
do
	local c = {
		snippet_lines = { "abcde" },
		expected_lines = { "abXcde" },
		target = { row = 0, col = 2 },
		key = "i",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 2 and r.end_col == 3 and not r.full_line, "i should highlight target character anchor")
end

do
	local c = {
		snippet_lines = { "abcde" },
		expected_lines = { "abcXde" },
		target = { row = 0, col = 2 },
		key = "a",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 2 and r.end_col == 3 and not r.full_line, "a should highlight target character anchor")
end

do
	local c = {
		snippet_lines = { "  value" },
		expected_lines = { "  xvalue" },
		target = { row = 0, col = 2 },
		key = "I",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 2 and r.end_col == 3 and not r.full_line, "I should highlight insertion anchor")
end

do
	local c = {
		snippet_lines = { "value" },
		expected_lines = { "value;" },
		target = { row = 0, col = 4 },
		key = "A",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 4 and r.end_col == 5 and not r.full_line, "A should highlight append anchor")
end

do
	local c = {
		snippet_lines = { "  const x = 1;" },
		expected_lines = { "  const x = 1;", "  return x;" },
		target = { row = 0, col = 2 },
		key = "o",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.full_line, "o should highlight target line")
end

do
	local c = {
		snippet_lines = { "  return x;" },
		expected_lines = { "  const x = 1;", "  return x;" },
		target = { row = 0, col = 2 },
		key = "O",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.full_line, "O should highlight target line")
end

do
	local c = {
		snippet_lines = { "  const value = 1;" },
		expected_lines = { "  const vaue = 1;" },
		target = { row = 0, col = 10 },
		key = "x",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 10 and r.end_col == 11 and not r.full_line, "x should highlight deleted character")
end

do
	local c = {
		snippet_lines = { "  const value = 1;" },
		expected_lines = { "  const valye = 1;" },
		target = { row = 0, col = 10 },
		key = "r",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 10 and r.end_col == 11 and not r.full_line, "r should highlight replaced character")
end

do
	local c = {
		snippet_lines = { "  Z value = 1;" },
		expected_lines = { "  let value = 1;" },
		target = { row = 0, col = 2 },
		key = "cl",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 2 and r.end_col == 3 and not r.full_line, "cl should highlight changed character")
end

do
	local c = {
		snippet_lines = { "  const foo = 1;" },
		expected_lines = { "  const bar = 1;" },
		target = { row = 0, col = 8 },
		select_end = { row = 0, col = 10 },
		key = "vc",
	}
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(r.start_col == 8 and r.end_col == 11 and not r.full_line, "vc should highlight visual selection range")
end

do
	local c = require("vimteacher.lessons.change_inside_brackets")._get_challenges()[9]
	local p = highlight_plan.compute_for_challenge(c)
	local r = effective_range(c, p)
	assert_test(
		r.end_col > r.start_col,
		string.format("empty ci{} should produce visible range, got start=%d end=%d", r.start_col, r.end_col)
	)
	assert_test(
		(r.end_col - r.start_col) >= 2,
		string.format("empty ci{} should highlight delimiters, got width %d", r.end_col - r.start_col)
	)
end

-- Sweep all static challenge pools for visibility + semantics
do
	for _, lesson_name in ipairs(lessons.order) do
		local mod = lessons.get_lesson(lesson_name)
		if mod and type(mod._get_challenges) == "function" then
			for idx, c in ipairs(mod._get_challenges()) do
				if c.target and c.snippet_lines and not c.highlight_rows then
					local plan = highlight_plan.compute_for_challenge(c)
					assert_visible(lesson_name, idx, c, plan)
					assert_semantics(lesson_name, idx, c, plan)
				end
			end
		end
	end
end

-- Sweep generated challenges from all lessons for visibility + semantics
do
	math.randomseed(12345)
	local buf = vim.api.nvim_create_buf(false, true)
	local ns = vim.api.nvim_create_namespace("test_highlight_plan")

	for _, lesson_name in ipairs(lessons.order) do
		local mod = lessons.get_lesson(lesson_name)
		if mod and type(mod.generate_challenge) == "function" then
			for i = 1, 80 do
				local c = mod.generate_challenge(buf, ns)
				if c and c.target and c.snippet_lines and not c.highlight_rows then
					local plan = highlight_plan.compute_for_challenge(c)
					assert_visible(lesson_name, i, c, plan)
					assert_semantics(lesson_name, i, c, plan)
				end
			end
		end
	end

	vim.api.nvim_buf_delete(buf, { force = true })
end

print(string.format("test_highlight_plan: %d passed, %d failed", pass_count, fail_count))
if fail_count > 0 then
	vim.cmd("cquit! 1")
end
