-- vimteacher/snippets.lua
-- Code snippet pool with recency-avoidance selection

local M = {}

-- 15 code snippets, 5-10 lines each, mixed languages
M.pool = {
	-- 1: Python function (7 lines)
	{
		"def calculate_total(items):",
		"    total = 0",
		"    for item in items:",
		"        price = item.get('price', 0)",
		"        quantity = item.get('qty', 1)",
		"        total += price * quantity",
		"    return total",
	},
	-- 2: JavaScript event handler (6 lines)
	{
		"document.addEventListener('click', (event) => {",
		"  const target = event.target;",
		"  if (target.classList.contains('btn')) {",
		"    handleButtonClick(target);",
		"  }",
		"});",
	},
	-- 3: Lua table merge (10 lines)
	{
		"local function merge(a, b)",
		"  local result = {}",
		"  for k, v in pairs(a) do",
		"    result[k] = v",
		"  end",
		"  for k, v in pairs(b) do",
		"    result[k] = v",
		"  end",
		"  return result",
		"end",
	},
	-- 4: Python class (8 lines)
	{
		"class Logger:",
		"    def __init__(self, name):",
		"        self.name = name",
		"        self.entries = []",
		"",
		"    def log(self, message):",
		"        entry = f'[{self.name}] {message}'",
		"        self.entries.append(entry)",
	},
	-- 5: Go error handling (10 lines)
	{
		"func readConfig(path string) (*Config, error) {",
		"    data, err := os.ReadFile(path)",
		"    if err != nil {",
		'        return nil, fmt.Errorf("read: %w", err)',
		"    }",
		"    var cfg Config",
		"    if err := json.Unmarshal(data, &cfg); err != nil {",
		"        return nil, err",
		"    }",
		"    return &cfg, nil",
	},
	-- 6: Rust match expression (8 lines)
	{
		"fn classify(score: u32) -> &'static str {",
		"    match score {",
		'        90..=100 => "excellent",',
		'        70..=89 => "good",',
		'        50..=69 => "average",',
		'        _ => "needs work",',
		"    }",
		"}",
	},
	-- 7: TypeScript interface (8 lines)
	{
		"interface User {",
		"  id: string;",
		"  name: string;",
		"  email: string;",
		"}",
		"",
		"function greet(user: User): string {",
		"  return `Hello, ${user.name}!`;",
	},
	-- 8: Python list processing (6 lines)
	{
		"def process_data(records):",
		"    valid = [r for r in records if r.active]",
		"    names = [r.name.strip() for r in valid]",
		"    unique = list(set(names))",
		"    unique.sort()",
		"    return unique",
	},
	-- 9: Shell script (9 lines)
	{
		"#!/bin/bash",
		"set -euo pipefail",
		"",
		'LOG_DIR="/var/log/app"',
		'mkdir -p "$LOG_DIR"',
		"",
		"for file in *.csv; do",
		'    echo "Processing $file"',
		'    wc -l "$file" >> "$LOG_DIR/counts.txt"',
	},
	-- 10: JavaScript async/await (10 lines)
	{
		"async function fetchUsers(apiUrl) {",
		"  try {",
		"    const response = await fetch(apiUrl);",
		"    const data = await response.json();",
		"    return data.users;",
		"  } catch (error) {",
		"    console.error('Failed:', error.message);",
		"    return [];",
		"  }",
		"}",
	},
	-- 11: SQL query (8 lines)
	{
		"SELECT",
		"    u.name,",
		"    u.email,",
		"    COUNT(o.id) AS order_count,",
		"    SUM(o.total) AS total_spent",
		"FROM users u",
		"LEFT JOIN orders o ON o.user_id = u.id",
		"GROUP BY u.id",
	},
	-- 12: YAML configuration (8 lines)
	{
		"server:",
		"  host: 0.0.0.0",
		"  port: 8080",
		"  workers: 4",
		"database:",
		"  url: postgres://localhost:5432/app",
		"  pool_size: 10",
		"  timeout: 30",
	},
	-- 13: HTML template (8 lines)
	{
		'<div class="card">',
		'  <h2 class="card-title">Welcome</h2>',
		'  <p class="card-body">',
		"    This is a simple card component",
		"    with multiple lines of content.",
		"  </p>",
		'  <button class="btn primary">Click Me</button>',
		"</div>",
	},
	-- 14: Go HTTP handler (9 lines)
	{
		"func handleHealth(w http.ResponseWriter, r *http.Request) {",
		"    if r.Method != http.MethodGet {",
		"        w.WriteHeader(http.StatusMethodNotAllowed)",
		"        return",
		"    }",
		'    w.Header().Set("Content-Type", "application/json")',
		"    w.WriteHeader(http.StatusOK)",
		'    w.Write([]byte(`{"status":"ok"}`))',
		"}",
	},
	-- 15: Python context manager (7 lines)
	{
		"class Timer:",
		"    def __enter__(self):",
		"        self.start = time.perf_counter()",
		"        return self",
		"",
		"    def __exit__(self, *args):",
		"        self.elapsed = time.perf_counter() - self.start",
	},
}

-- Track recently used snippet indices to avoid repeats
local recent_picker = require("vimteacher.recent")
local recent = {}
local MAX_RECENT = 5

--- Reset the recency tracker (call at lesson start)
function M.reset_recent()
	recent_picker.clear(recent)
end

--- Get a random snippet from the pool, avoiding recent picks.
--- Returns a COPY of the snippet (table of strings).
function M.get_random()
	local idx = recent_picker.pick_avoiding_recent(#M.pool, recent, MAX_RECENT)

	-- Return a copy
	local copy = {}
	for _, line in ipairs(M.pool[idx]) do
		copy[#copy + 1] = line
	end
	return copy
end

return M
