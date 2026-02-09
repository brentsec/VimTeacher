-- vimteacher/lessons/paragraph_jumps.lua
-- Lesson: Jumping between paragraphs with } and {

local M = {}

M.title = "Paragraph Jumps: }, {"

M.dwell_time = 50

M.description = {
  "Jump between paragraphs using } and { commands.",
  "",
  "  } = jump to next blank line (paragraph forward)",
  "  { = jump to previous blank line (paragraph backward)",
  "",
  "A paragraph is separated by blank lines (empty lines with no content).",
  "This is useful for navigating through code blocks, function definitions,",
  "and documentation comments.",
  "",
  "Move your cursor to the green highlighted target below.",
}

M.hint_lines = {
  "[}] Next paragraph  [{] Previous paragraph — Move to the green target",
}

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
    "import \"fmt\"",
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

--- Compute the minimum (optimal) moves between two positions.
--- For paragraph jumps, if on same row, just position cursor (1 move).
--- If on different rows, jump to paragraph + position (2 moves).
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  if start_pos.row == target.row and start_pos.col == target.col then
    return 0
  end
  if start_pos.row == target.row then
    return 1 -- Same row, just reposition column
  end
  if start_pos.col == target.col then
    return 1 -- Different row, same column (paragraph jump lands there)
  end
  return 2 -- Different row and column (paragraph jump + column adjustment)
end

--- Generate a new challenge: pick snippet with paragraphs + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
  local snippet = SNIPPETS[math.random(1, #SNIPPETS)]

  -- Build list of all valid target positions (non-whitespace characters, exclude blank lines)
  local valid_positions = {}
  for row_idx, line in ipairs(snippet) do
    if line ~= "" then -- Skip blank lines
      for col_idx = 1, #line do
        local char = line:sub(col_idx, col_idx)
        if char ~= " " and char ~= "\t" then
          valid_positions[#valid_positions + 1] = {
            row = row_idx - 1, -- 0-indexed
            col = col_idx - 1, -- 0-indexed
          }
        end
      end
    end
  end

  -- Safety: if no valid positions, retry with different snippet
  if #valid_positions == 0 then
    return M.generate_challenge(buf, ns_id)
  end

  -- Pick a random target
  local target = valid_positions[math.random(1, #valid_positions)]

  -- Pick a starting position at least 3 rows from target
  local candidates = {}
  for _, pos in ipairs(valid_positions) do
    local row_dist = math.abs(pos.row - target.row)
    if row_dist >= 3 then
      candidates[#candidates + 1] = { row = pos.row, col = pos.col, row_dist = row_dist }
    end
  end

  local start_pos
  if #candidates == 0 then
    -- Fallback: use first char of first non-empty line
    for i, line in ipairs(snippet) do
      if line ~= "" and #line > 0 then
        start_pos = { row = i - 1, col = 0 }
        break
      end
    end
  else
    -- Prefer positions around 5-7 rows away for interesting paragraph jumps
    table.sort(candidates, function(a, b)
      return math.abs(a.row_dist - 6) < math.abs(b.row_dist - 6)
    end)
    local top_n = math.min(5, #candidates)
    local chosen = candidates[math.random(1, top_n)]
    start_pos = { row = chosen.row, col = chosen.col }
  end

  return {
    snippet_lines = snippet,
    target = target,
    start_pos = start_pos,
  }
end

return M
