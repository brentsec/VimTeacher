-- vimteacher/lessons/insert_mode.lua
-- Third lesson: Entering insert mode with i and a

local M = {}

M.title = "Insert Mode: i, a"
M.type = "insert"
M.allowed_keys = { "i", "a" }
M.challenges_required = 10

M.description = {
	"Vim starts in normal mode. To type text, enter insert mode.",
	"",
	"  i = insert before cursor    a = append after cursor",
	"",
	"After editing, press <Esc> to return to normal mode.",
	"",
	"Navigate to the green target, use i or a to fix the code,",
	"then press <Esc> when done.",
}

M.hint_lines = {
	"[i] Insert before cursor  [a] Append after cursor  [Esc] Return to normal mode",
}

-- Pre-defined challenge pool. Each challenge has a "broken" snippet and the expected fix.
-- target = where to navigate (0-indexed {row, col})
-- For `i` challenges: target is the char AFTER the insertion point (i inserts before cursor)
-- For `a` challenges: target is the char BEFORE the insertion point (a appends after cursor)
local CHALLENGES = {
	-- Challenge 1: i — insert 't' before 'e' in 'esting'
	{
		snippet_lines = {
			"function runTests() {",
			"  const esting = 'unit';",
			"  return esting;",
			"}",
		},
		expected_lines = {
			"function runTests() {",
			"  const testing = 'unit';",
			"  return esting;",
			"}",
		},
		target = { row = 1, col = 8 }, -- the 'e' in 'esting'
		start_pos = { row = 0, col = 0 },
		key = "i",
		char = "t",
	},

	-- Challenge 2: i — insert 'g' before 'e' in 'etData'
	{
		snippet_lines = {
			"async function etData(url) {",
			"  const res = await fetch(url);",
			"  return res.json();",
			"}",
		},
		expected_lines = {
			"async function getData(url) {",
			"  const res = await fetch(url);",
			"  return res.json();",
			"}",
		},
		target = { row = 0, col = 15 }, -- the 'e' in 'etData'
		start_pos = { row = 2, col = 0 },
		key = "i",
		char = "g",
	},

	-- Challenge 3: i — insert 'r' before 'n' in 'retun'
	{
		snippet_lines = {
			"function add(a, b) {",
			"  const sum = a + b;",
			"  retun sum;",
			"}",
		},
		expected_lines = {
			"function add(a, b) {",
			"  const sum = a + b;",
			"  return sum;",
			"}",
		},
		target = { row = 2, col = 6 }, -- the 'n' in 'retun'
		start_pos = { row = 0, col = 0 },
		key = "i",
		char = "r",
	},

	-- Challenge 4: a — append 'g' after 'n' in 'testin'
	{
		snippet_lines = {
			"function validate(input) {",
			"  const testin = input.trim();",
			"  return testin.length > 0;",
			"}",
		},
		expected_lines = {
			"function validate(input) {",
			"  const testing = input.trim();",
			"  return testin.length > 0;",
			"}",
		},
		target = { row = 1, col = 13 }, -- the 'n' in 'testin'
		start_pos = { row = 2, col = 0 },
		key = "a",
		char = "g",
	},

	-- Challenge 5: a — append 'g' after 'o' in 'lo'
	{
		snippet_lines = {
			"function debug(message) {",
			"  console.lo(message);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function debug(message) {",
			"  console.log(message);",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 11 }, -- the 'o' in 'lo'
		start_pos = { row = 0, col = 0 },
		key = "a",
		char = "g",
	},

	-- Challenge 6: a — append 't' after 'n' in 'coun'
	{
		snippet_lines = {
			"function counter(items) {",
			"  let coun = 0;",
			"  for (const item of items) {",
			"    coun += 1;",
			"  }",
			"  return coun;",
			"}",
		},
		expected_lines = {
			"function counter(items) {",
			"  let count = 0;",
			"  for (const item of items) {",
			"    coun += 1;",
			"  }",
			"  return coun;",
			"}",
		},
		target = { row = 1, col = 9 }, -- the 'n' in 'coun'
		start_pos = { row = 3, col = 0 },
		key = "a",
		char = "t",
	},

	-- Challenge 7: i — insert '(' before ')'
	{
		snippet_lines = {
			"function check(user) {",
			"  if user.isAdmin) {",
			"    return true;",
			"  }",
			"}",
		},
		expected_lines = {
			"function check(user) {",
			"  if (user.isAdmin) {",
			"    return true;",
			"  }",
			"}",
		},
		target = { row = 1, col = 5 }, -- the 'u' in 'user' (insert '(' before it)
		start_pos = { row = 3, col = 0 },
		key = "i",
		char = "(",
	},

	-- Challenge 8: a — append '+' after '+' in 'i+'
	{
		snippet_lines = {
			"function loop(len) {",
			"  for (let i = 0; i < len; i+) {",
			"    process(i);",
			"  }",
			"}",
		},
		expected_lines = {
			"function loop(len) {",
			"  for (let i = 0; i < len; i++) {",
			"    process(i);",
			"  }",
			"}",
		},
		target = { row = 1, col = 28 }, -- the '+' in 'i+'
		start_pos = { row = 0, col = 0 },
		key = "a",
		char = "+",
	},

	-- Challenge 9: i — insert 'm' before 'a' in 'ap'
	{
		snippet_lines = {
			"function transform(data) {",
			"  const items = data.ap(x => x * 2);",
			"  return items;",
			"}",
		},
		expected_lines = {
			"function transform(data) {",
			"  const items = data.map(x => x * 2);",
			"  return items;",
			"}",
		},
		target = { row = 1, col = 21 }, -- the 'a' in 'ap'
		start_pos = { row = 2, col = 0 },
		key = "i",
		char = "m",
	},

	-- Challenge 10: a — append 'l' after 'i' in 'emai'
	{
		snippet_lines = {
			"function getUser(id) {",
			"  const user = db.find(id);",
			"  return { name: user.name, emai: user.emai };",
			"}",
		},
		expected_lines = {
			"function getUser(id) {",
			"  const user = db.find(id);",
			"  return { name: user.name, email: user.emai };",
			"}",
		},
		target = { row = 2, col = 31 }, -- the 'i' in first 'emai'
		start_pos = { row = 0, col = 0 },
		key = "a",
		char = "l",
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- Uses counted Vim motions: {n}j/k for row, {n}w/l/f for column.
--- Each counted motion triggers 1 CursorMoved event.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	local row_diff = start_pos.row ~= target.row
	local col_diff = start_pos.col ~= target.col
	if not row_diff and not col_diff then
		return 0
	end
	if not row_diff or not col_diff then
		return 1
	end
	return 2
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
	-- Build list of eligible indices (not recently used)
	local eligible = {}
	for i = 1, #CHALLENGES do
		local dominated = false
		for _, r in ipairs(recent) do
			if r == i then
				dominated = true
				break
			end
		end
		if not dominated then
			eligible[#eligible + 1] = i
		end
	end

	-- If all are recent, reset
	if #eligible == 0 then
		recent = {}
		for i = 1, #CHALLENGES do
			eligible[#eligible + 1] = i
		end
	end

	-- Pick random eligible challenge
	local idx = eligible[math.random(1, #eligible)]

	-- Update recency
	recent[#recent + 1] = idx
	if #recent > MAX_RECENT then
		table.remove(recent, 1)
	end

	local c = CHALLENGES[idx]
	return {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		char = c.char,
	}
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
