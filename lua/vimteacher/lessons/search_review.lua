-- vimteacher/lessons/search_review.lua
-- Search review lesson: practice all search commands

local M = {}

M.title = "Search Review"

M.dwell_time = 50

M.description = {
  "Practice all the search commands you have learned:",
  "",
  "  /text   = search forward     ?text   = search backward",
  "  n       = next match         N       = previous match",
  "  *       = search word forward  #     = search word backward",
  "",
  "Use whichever search method gets you to the target fastest.",
  "",
  "Move your cursor to the green highlighted target.",
}

M.hint_lines = {
  "[/] Forward  [?] Backward  [n/N] Repeat  [*/#] Word search",
}

-- Custom snippets with repeated keywords for search practice
local SEARCH_SNIPPETS = {
  {
    "function validate_input(data) {",
    "  if (!data) return false;",
    "  const result = process_data(data);",
    "  if (!result.valid) return false;",
    "  const output = format_data(result.data);",
    "  return save_data(output);",
    "  // data appears 5 times",
    "}",
  },
  {
    "class UserManager {",
    "  constructor() {",
    "    this.users = [];",
    "    this.cache = new Map();",
    "  }",
    "  addUser(user) { this.users.push(user); }",
    "  findUser(id) { return this.users.find(u => u.id === id); }",
    "  removeUser(id) { this.users = this.users.filter(u => u.id !== id); }",
    "}",
  },
  {
    "def calculate_total(items):",
    "    total = 0",
    "    for item in items:",
    "        if item.valid:",
    "            total += item.price * item.quantity",
    "        else:",
    "            print(f'Invalid item: {item.name}')",
    "    return total",
    "# total, item repeated",
  },
  {
    "SELECT customer.name, customer.email",
    "FROM customer",
    "JOIN order ON order.customer_id = customer.id",
    "WHERE customer.active = true",
    "  AND order.status = 'complete'",
    "  AND customer.country = 'US'",
    "ORDER BY customer.name;",
    "-- customer appears 6 times",
  },
  {
    "const config = {",
    "  api: { url: 'https://api.example.com', timeout: 5000 },",
    "  cache: { enabled: true, ttl: 3600 },",
    "  retry: { max: 3, delay: 1000 },",
    "  logging: { level: 'info', enabled: true },",
    "  features: { beta: false, debug: false }",
    "};",
    "// enabled, false repeated",
  },
  {
    "package main",
    "",
    "import \"fmt\"",
    "",
    "func main() {",
    "    result := compute(10, 20)",
    "    fmt.Println(result)",
    "    another := compute(5, result)",
    "    fmt.Println(another)",
    "}",
  },
  {
    "public class Database {",
    "    private Connection conn;",
    "    private String host;",
    "    private int port;",
    "",
    "    public void connect(String host, int port) {",
    "        this.host = host;",
    "        this.port = port;",
    "        this.conn = createConnection(host, port);",
    "    }",
    "}",
  },
  {
    "for (int index = 0; index < array.length; index++) {",
    "    if (array[index] == target) {",
    "        found = true;",
    "        position = index;",
    "        break;",
    "    }",
    "    if (array[index] < min) min = array[index];",
    "}",
    "// index, array repeated",
  },
}

--- Compute the optimal moves for search.
--- Search is always 1 action (one search command).
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
  if start_pos.row == target.row and start_pos.col == target.col then
    return 0
  end
  return 1 -- search is always 1 action
end

--- Generate a new challenge: random snippet + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
  local snippet = SEARCH_SNIPPETS[math.random(1, #SEARCH_SNIPPETS)]

  -- Build list of all valid target positions (non-whitespace characters)
  local valid_positions = {}
  for row_idx, line in ipairs(snippet) do
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

  -- Safety: if no valid positions (should never happen), retry
  if #valid_positions == 0 then
    return M.generate_challenge(buf, ns_id)
  end

  -- Pick a random target
  local target = valid_positions[math.random(1, #valid_positions)]

  -- Pick a starting position different from target
  local candidates = {}
  for _, pos in ipairs(valid_positions) do
    if pos.row ~= target.row or pos.col ~= target.col then
      candidates[#candidates + 1] = { row = pos.row, col = pos.col }
    end
  end

  local start_pos
  if #candidates == 0 then
    -- Fallback: use first char of first non-empty line
    for i, line in ipairs(snippet) do
      if #line > 0 then
        start_pos = { row = i - 1, col = 0 }
        break
      end
    end
  else
    -- Pick random start position
    local chosen = candidates[math.random(1, #candidates)]
    start_pos = { row = chosen.row, col = chosen.col }
  end

  return {
    snippet_lines = snippet,
    target = target,
    start_pos = start_pos,
  }
end

return M
