-- tests/test_highlight.lua
-- Tests for highlight target range rendering edge cases

local highlight = require("vimteacher.highlight")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

local function get_target_mark(buf)
	local marks = vim.api.nvim_buf_get_extmarks(buf, highlight.ns_target, 0, -1, { details = true })
	if #marks ~= 1 then
		return nil, #marks
	end
	return marks[1]
end

print("test_highlight: running...")

local original_set_hl = vim.api.nvim_set_hl
local hl_specs = {}
vim.api.nvim_set_hl = function(ns, name, spec)
	hl_specs[name] = vim.deepcopy(spec)
	return original_set_hl(ns, name, spec)
end

highlight.setup()
vim.api.nvim_set_hl = original_set_hl

for _, group in ipairs({
	"VimTeacherTitle",
	"VimTeacherSeparator",
	"VimTeacherTarget",
	"VimTeacherSuccess",
	"VimTeacherProgress",
	"VimTeacherTimer",
	"VimTeacherHint",
	"VimTeacherComplete",
	"VimTeacherStatsHeader",
	"VimTeacherMenuItem",
	"VimTeacherMenuNumber",
	"VimTeacherLogo1",
	"VimTeacherLogo2",
	"VimTeacherLogo3",
	"VimTeacherLogo4",
	"VimTeacherLogo5",
	"VimTeacherBorder",
	"VimTeacherSubtitle",
	"VimTeacherMenuText",
	"VimTeacherMenuStat",
	"VimTeacherMenuSep",
	"VimTeacherMenuSection",
	"VimTeacherInsertHint",
	"VimTeacherGoalText",
	"VimTeacherSearchTarget",
}) do
	assert_test(hl_specs[group] ~= nil, "Expected setup to define highlight group " .. group)
	if hl_specs[group] then
		assert_test(hl_specs[group].default == true, group .. " should use default=true")
	end
end

local buf = vim.api.nvim_create_buf(false, true)
vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
	"abcdef",
	"z",
})

-- Test 1: Default end_col highlights one character
highlight.place_target(buf, 0, 2)
local mark, count = get_target_mark(buf)
assert_test(mark ~= nil, "Expected one target extmark, got " .. tostring(count))
if mark then
	assert_test(mark[2] == 0, "Expected row 0, got " .. mark[2])
	assert_test(mark[3] == 2, "Expected start col 2, got " .. mark[3])
	assert_test(mark[4].end_col == 3, "Expected end_col 3, got " .. tostring(mark[4].end_col))
end

-- Test 2: Zero-width range (end_col == start_col) is normalized to visible width
highlight.place_target(buf, 0, 2, 2)
mark, count = get_target_mark(buf)
assert_test(mark ~= nil, "Expected one target extmark for zero-width case, got " .. tostring(count))
if mark then
	assert_test(
		mark[4].end_col == 3,
		"Zero-width range should normalize to end_col 3, got " .. tostring(mark[4].end_col)
	)
end

-- Test 3: Negative-width range (end_col < start_col) is normalized to visible width
highlight.place_target(buf, 0, 2, 1)
mark, count = get_target_mark(buf)
assert_test(mark ~= nil, "Expected one target extmark for negative-width case, got " .. tostring(count))
if mark then
	assert_test(
		mark[4].end_col == 3,
		"Negative-width range should normalize to end_col 3, got " .. tostring(mark[4].end_col)
	)
end

-- Test 4: Overlong end_col is clamped to line length
highlight.place_target(buf, 0, 4, 99)
mark, count = get_target_mark(buf)
assert_test(mark ~= nil, "Expected one target extmark for overlong range, got " .. tostring(count))
if mark then
	assert_test(mark[4].end_col == 6, "Overlong range should clamp to end_col 6, got " .. tostring(mark[4].end_col))
end

-- Test 5: Single-char line still renders for zero-width input
highlight.place_target(buf, 1, 0, 0)
mark, count = get_target_mark(buf)
assert_test(mark ~= nil, "Expected one target extmark on single-char line, got " .. tostring(count))
if mark then
	assert_test(mark[2] == 1, "Expected row 1, got " .. mark[2])
	assert_test(mark[3] == 0, "Expected start col 0, got " .. mark[3])
	assert_test(mark[4].end_col == 1, "Expected end_col 1, got " .. tostring(mark[4].end_col))
end

-- Test 6: Out-of-bounds target column does not create extmark
highlight.place_target(buf, 0, 99, 100)
local marks = vim.api.nvim_buf_get_extmarks(buf, highlight.ns_target, 0, -1, { details = true })
assert_test(#marks == 0, "Out-of-bounds target should create no extmark, got " .. #marks)

vim.api.nvim_buf_delete(buf, { force = true })

counter.finish("test_highlight")
