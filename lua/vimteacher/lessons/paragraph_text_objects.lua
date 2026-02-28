-- vimteacher/lessons/paragraph_text_objects.lua
-- Eighth lesson: Paragraph text objects (dip, dap, cip, cap)

local M = {}

M.title = "Paragraph Objects: dip, dap"
M.type = "insert"
M.allowed_keys = { "c" }
M.allowed_modify_keys = { "d" }
M.challenges_required = 10

M.description = {
	"Act on entire blocks of text separated by blank lines:",
	"",
	"  dip = delete inner paragraph (the whole code block)",
	"  dap = delete a paragraph (block + the blank line after it)",
	"  cip = change inner paragraph (delete block, type replacement)",
	"  cap = change a paragraph (delete block + blank line, type)",
	"",
	"  A 'paragraph' is a group of non-blank lines. Blank lines",
	"  are the boundaries between paragraphs.",
	"",
	"Navigate into the target block and use the indicated command.",
}

M.hint_lines = {
	"[dip] Del block  [dap] Del block+blank  [cip] Change block  [q] Menu",
}

-- Pre-defined challenge pool with multi-paragraph snippets
local CHALLENGES = {
	-- Challenge 1: dip - delete debug block
	{
		snippet_lines = {
			"const a = 1;",
			"const b = 2;",
			"",
			"// debug block - delete this",
			"console.log(a);",
			"console.log(b);",
			"",
			"return a + b;",
		},
		expected_lines = {
			"const a = 1;",
			"const b = 2;",
			"",
			"",
			"return a + b;",
		},
		target = { row = 4, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "dip",
	},

	-- Challenge 2: dap - delete temp vars block + blank line
	{
		snippet_lines = {
			"function calculate() {",
			"  const x = getValue();",
			"",
			"  // temp vars",
			"  const temp1 = x * 2;",
			"  const temp2 = temp1 + 5;",
			"",
			"  return finalValue;",
			"}",
		},
		expected_lines = {
			"function calculate() {",
			"  const x = getValue();",
			"",
			"  return finalValue;",
			"}",
		},
		target = { row = 4, col = 2 },
		start_pos = { row = 8, col = 0 },
		key = "dap",
	},

	-- Challenge 3: dip - delete comment block
	{
		snippet_lines = {
			"class Widget {",
			"  constructor() {",
			"    this.id = 0;",
			"  }",
			"",
			"  // Old implementation",
			"  // TODO: remove",
			"  // No longer needed",
			"",
			"  render() {",
			"    return this.id;",
			"  }",
			"}",
		},
		expected_lines = {
			"class Widget {",
			"  constructor() {",
			"    this.id = 0;",
			"  }",
			"",
			"",
			"  render() {",
			"    return this.id;",
			"  }",
			"}",
		},
		target = { row = 6, col = 5 },
		start_pos = { row = 0, col = 0 },
		key = "dip",
	},

	-- Challenge 4: dap - delete imports block
	{
		snippet_lines = {
			"import { React } from 'react';",
			"",
			"// unused imports",
			"import { oldUtil } from './old';",
			"import { deprecated } from './dep';",
			"",
			"export default App;",
		},
		expected_lines = {
			"import { React } from 'react';",
			"",
			"export default App;",
		},
		target = { row = 3, col = 10 },
		start_pos = { row = 6, col = 0 },
		key = "dap",
	},

	-- Challenge 5: cip - replace logging block
	{
		snippet_lines = {
			"function process(data) {",
			"  const result = transform(data);",
			"",
			"  console.log('debug');",
			"  console.log(result);",
			"  console.log('end');",
			"",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process(data) {",
			"  const result = transform(data);",
			"",
			"  // logging removed",
			"",
			"  return result;",
			"}",
		},
		target = { row = 4, col = 2 },
		start_pos = { row = 0, col = 0 },
		key = "cip",
		char = "  // logging removed",
	},

	-- Challenge 6: cap - replace error handling block
	{
		snippet_lines = {
			"try {",
			"  execute();",
			"}",
			"",
			"catch (err) {",
			"  console.error(err);",
			"  throw err;",
			"}",
			"",
			"finally {",
			"  cleanup();",
			"}",
		},
		expected_lines = {
			"try {",
			"  execute();",
			"}",
			"",
			"// error handling updated",
			"finally {",
			"  cleanup();",
			"}",
		},
		target = { row = 5, col = 2 },
		start_pos = { row = 11, col = 0 },
		key = "cap",
		char = "// error handling updated",
	},

	-- Challenge 7: dip - delete validation block
	{
		snippet_lines = {
			"function save(item) {",
			"",
			"  if (!item) return;",
			"  if (!item.id) return;",
			"  if (!item.name) return;",
			"",
			"  database.save(item);",
			"}",
		},
		expected_lines = {
			"function save(item) {",
			"",
			"",
			"  database.save(item);",
			"}",
		},
		target = { row = 3, col = 5 },
		start_pos = { row = 7, col = 0 },
		key = "dip",
	},

	-- Challenge 8: dap - delete initialization block
	{
		snippet_lines = {
			"let config = {};",
			"",
			"config.host = 'localhost';",
			"config.port = 3000;",
			"config.debug = true;",
			"",
			"startServer(config);",
		},
		expected_lines = {
			"let config = {};",
			"",
			"startServer(config);",
		},
		target = { row = 2, col = 0 },
		start_pos = { row = 0, col = 0 },
		key = "dap",
	},

	-- Challenge 9: cip - replace setup code
	{
		snippet_lines = {
			"describe('tests', () => {",
			"",
			"  beforeEach(() => {",
			"    setupMocks();",
			"    initDatabase();",
			"  });",
			"",
			"  it('works', () => {",
			"    expect(true).toBe(true);",
			"  });",
			"}",
		},
		expected_lines = {
			"describe('tests', () => {",
			"",
			"  // setup simplified",
			"",
			"  it('works', () => {",
			"    expect(true).toBe(true);",
			"  });",
			"}",
		},
		target = { row = 3, col = 4 },
		start_pos = { row = 10, col = 0 },
		key = "cip",
		char = "  // setup simplified",
	},

	-- Challenge 10: cap - replace middleware block
	{
		snippet_lines = {
			"app.use(cors());",
			"",
			"app.use(logger());",
			"app.use(session());",
			"app.use(auth());",
			"",
			"app.listen(3000);",
		},
		expected_lines = {
			"app.use(cors());",
			"",
			"app.use(basicMiddleware());",
			"app.listen(3000);",
		},
		target = { row = 3, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "cap",
		char = "app.use(basicMiddleware());",
	},
}

-- Track recently used challenges to avoid repetition
local recent = {}
local MAX_RECENT = 5

--- Compute the minimum (optimal) moves between two positions.
--- For paragraph operations, user can be anywhere in target paragraph.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	local moves = 0
	if start_pos.row ~= target.row then
		moves = moves + 1
	end
	if start_pos.col ~= target.col then
		moves = moves + 1
	end
	return moves + 1 -- navigation + 1 operation
end

--- Generate a new challenge: pick from the pre-defined pool with recency avoidance.
--- @param buf number Buffer handle (unused, part of interface)
--- @param ns_id number Namespace ID (unused, part of interface)
--- @return table challenge {snippet_lines, expected_lines, target, start_pos, key, char?}
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

	-- Compute highlight_rows: paragraph ops delete/change entire lines,
	-- so we need multi-row highlighting instead of single-char highlighting.
	local highlight_rows = {}
	local top = 0
	for i = 1, math.min(#c.snippet_lines, #c.expected_lines) do
		if c.snippet_lines[i] == c.expected_lines[i] then
			top = i
		else
			break
		end
	end
	local bot = 0
	for i = 0, math.min(#c.snippet_lines, #c.expected_lines) - top - 1 do
		if c.snippet_lines[#c.snippet_lines - i] == c.expected_lines[#c.expected_lines - i] then
			bot = i + 1
		else
			break
		end
	end
	for i = top + 1, #c.snippet_lines - bot do
		highlight_rows[#highlight_rows + 1] = i - 1 -- 0-indexed
	end

	local result = {
		snippet_lines = vim.deepcopy(c.snippet_lines),
		expected_lines = vim.deepcopy(c.expected_lines),
		target = { row = c.target.row, col = c.target.col },
		start_pos = { row = c.start_pos.row, col = c.start_pos.col },
		key = c.key,
		highlight_rows = highlight_rows,
	}

	if c.char then
		result.char = c.char
	end

	return result
end

--- Expose challenge pool for testing.
function M._get_challenges()
	return CHALLENGES
end

return M
