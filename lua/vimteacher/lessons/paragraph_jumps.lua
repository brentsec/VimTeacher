-- vimteacher/lessons/paragraph_jumps.lua
-- Lesson: Jumping between paragraphs with } and {

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Paragraph Jumps: {{forward}}, {{backward}}",
	dwell_time = 50,
	description_template = {
		"Jump between paragraphs using {{forward}} and {{backward}} commands.",
		"",
		"  {{forward}} = jump to next blank line (paragraph forward)",
		"  {{backward}} = jump to previous blank line (paragraph backward)",
		"",
		"A paragraph is separated by blank lines (empty lines with no content).",
		"This is useful for navigating through code blocks, function definitions,",
		"and documentation comments.",
		"",
		"Move your cursor to the green highlighted target below.",
	},
	hint_template = {
		"[{{forward}}] Next paragraph  [{{backward}}] Previous paragraph — Move to the green target",
	},
	template_tokens = {
		forward = "}",
		backward = "{",
	},
})
-- Local snippets with paragraph boundaries (blank lines)
local SNIPPETS = {
	{
		"function calculateTotal(items) {",
		"  let sum = 0;",
		"  for (const item of items) {",
		"    sum += item.price;",
		"  }",
		"  return sum;",
		"}",
		"",
		"function applyDiscount(total, rate) {",
		"  return total * (1 - rate);",
		"}",
		"",
		"const cart = [{price: 10}, {price: 20}];",
		"const total = calculateTotal(cart);",
		"console.log(applyDiscount(total, 0.1));",
	},
	{
		"class UserAccount {",
		"  constructor(name, email) {",
		"    this.name = name;",
		"    this.email = email;",
		"  }",
		"",
		"  getDisplayName() {",
		"    return this.name;",
		"  }",
		"}",
		"",
		"const user = new UserAccount('Alice', 'alice@example.com');",
		"console.log(user.getDisplayName());",
	},
	{
		"def process_data(items):",
		"    results = []",
		"    for item in items:",
		"        results.append(item * 2)",
		"    return results",
		"",
		"def validate_input(data):",
		"    if not data:",
		"        return False",
		"    return len(data) > 0",
		"",
		"data = [1, 2, 3, 4, 5]",
		"if validate_input(data):",
		"    print(process_data(data))",
	},
	{
		"package main",
		"",
		'import "fmt"',
		"",
		"func add(a, b int) int {",
		"    return a + b",
		"}",
		"",
		"func multiply(a, b int) int {",
		"    return a * b",
		"}",
		"",
		"func main() {",
		"    result := add(3, 4)",
		"    fmt.Println(multiply(result, 2))",
		"}",
	},
	{
		"// Configuration settings",
		"const config = {",
		"  apiUrl: 'https://api.example.com',",
		"  timeout: 5000,",
		"};",
		"",
		"// Helper function",
		"function fetchData(endpoint) {",
		"  return fetch(`${config.apiUrl}/${endpoint}`);",
		"}",
		"",
		"// Main application logic",
		"async function initialize() {",
		"  const data = await fetchData('users');",
		"  return data.json();",
		"}",
	},
	{
		"struct Point {",
		"    x: i32,",
		"    y: i32,",
		"}",
		"",
		"impl Point {",
		"    fn new(x: i32, y: i32) -> Point {",
		"        Point { x, y }",
		"    }",
		"",
		"    fn distance(&self, other: &Point) -> f64 {",
		"        let dx = (self.x - other.x) as f64;",
		"        let dy = (self.y - other.y) as f64;",
		"        (dx * dx + dy * dy).sqrt()",
		"    }",
		"}",
	},
	{
		"import java.util.List;",
		"import java.util.ArrayList;",
		"",
		"public class DataProcessor {",
		"    private List<String> items;",
		"",
		"    public DataProcessor() {",
		"        this.items = new ArrayList<>();",
		"    }",
		"",
		"    public void addItem(String item) {",
		"        items.add(item);",
		"    }",
		"",
		"    public int getCount() {",
		"        return items.size();",
		"    }",
		"}",
	},
	{
		"-- Database query helper",
		"local function buildQuery(table, conditions)",
		"  local query = 'SELECT * FROM ' .. table",
		"  if conditions then",
		"    query = query .. ' WHERE ' .. conditions",
		"  end",
		"  return query",
		"end",
		"",
		"-- Execute and fetch results",
		"local function executeQuery(db, query)",
		"  local stmt = db:prepare(query)",
		"  local results = {}",
		"  for row in stmt:nrows() do",
		"    table.insert(results, row)",
		"  end",
		"  return results",
		"end",
	},
}

-- Track blank line positions for the current challenge (used by compute_optimal)
local _current_blank_lines = {}

--- Compute the minimum number of } or { presses to reach the target blank line.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed (always a blank line at col 0)
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row then
		return 0
	end

	-- Count } presses needed (forward): blank lines between start (exclusive) and target (inclusive)
	local forward = 0
	if target.row > start_pos.row then
		for _, bl in ipairs(_current_blank_lines) do
			if bl > start_pos.row and bl <= target.row then
				forward = forward + 1
			end
		end
	end

	-- Count { presses needed (backward): blank lines between target (inclusive) and start (exclusive)
	local backward = 0
	if target.row < start_pos.row then
		for _, bl in ipairs(_current_blank_lines) do
			if bl >= target.row and bl < start_pos.row then
				backward = backward + 1
			end
		end
	end

	if forward > 0 and backward > 0 then
		return math.min(forward, backward)
	end
	return forward > 0 and forward or backward
end

--- Generate a new challenge: pick snippet, target a blank line, start on a non-blank line.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos, highlight_rows}
function M.generate_challenge()
	local snippet = SNIPPETS[math.random(1, #SNIPPETS)]

	-- Find all blank line rows (0-indexed)
	local blank_lines = {}
	for row_idx, line in ipairs(snippet) do
		if line == "" then
			blank_lines[#blank_lines + 1] = row_idx - 1
		end
	end

	-- Safety: if no blank lines, retry with different snippet
	if #blank_lines == 0 then
		return M.generate_challenge()
	end

	-- Pick a random blank line as target
	local target_row = blank_lines[math.random(1, #blank_lines)]
	local target = { row = target_row, col = 0 }

	-- Build list of non-blank line positions for start candidates
	local non_blank = {}
	for row_idx, line in ipairs(snippet) do
		if line ~= "" then
			non_blank[#non_blank + 1] = row_idx - 1
		end
	end

	-- Pick a starting position at least 3 rows from target
	local candidates = {}
	for _, row in ipairs(non_blank) do
		local row_dist = math.abs(row - target_row)
		if row_dist >= 3 then
			candidates[#candidates + 1] = { row = row, dist = row_dist }
		end
	end

	local start_pos
	if #candidates == 0 then
		-- Fallback: use first non-blank line
		start_pos = { row = non_blank[1] or 0, col = 0 }
	else
		-- Prefer positions around 5-7 rows away for interesting paragraph jumps
		table.sort(candidates, function(a, b)
			return math.abs(a.dist - 6) < math.abs(b.dist - 6)
		end)
		local top_n = math.min(5, #candidates)
		local chosen = candidates[math.random(1, top_n)]
		start_pos = { row = chosen.row, col = 0 }
	end

	-- Store blank lines for compute_optimal
	_current_blank_lines = blank_lines

	return {
		snippet_lines = snippet,
		target = target,
		start_pos = start_pos,
		highlight_rows = { target_row },
		goal_text = "Jump to the highlighted blank line",
	}
end

return M
