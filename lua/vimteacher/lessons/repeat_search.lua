-- vimteacher/lessons/repeat_search.lua
-- Repeat Search: n, N

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Repeat Search: {{n}}, {{N}}",
	template_tokens = {
		["?"] = "?",
		["/"] = "/",
		n = "n",
		N = "N",
	},
	dwell_time = 50,
	description_template = {
	"After searching with {{/}} or {{?}}, repeat the search instantly:",
	"",
	"  {{n}} = jump to the NEXT match (same direction)",
	"  {{N}} = jump to the PREVIOUS match (opposite direction)",
	"",
	"  Example: type {{/}}return then Enter to find 'return'.",
	"  Now press {{n}} to jump to the next 'return' in the file.",
	"  Press {{N}} to go back to the previous one.",
	"",
	"Move your cursor to the green highlighted target.",
	},
	hint_template = {
		"[{{n}}] Next match  [{{N}}] Previous match  [{{/}}text] New search",
	},
})

-- Custom snippets with deliberately repeated keywords
local SNIPPETS = {
	{
		"const data = fetchData();",
		"const items = data.items;",
		"for (const item of items) {",
		"  processItem(item);",
		"  logData(item.data);",
		"  validateData(data);",
		"}",
		"return data;",
	},
	{
		"function processResults(results) {",
		"  const validResults = results.filter(r => r.valid);",
		"  const sortedResults = sortResults(validResults);",
		"  for (const result of sortedResults) {",
		"    console.log(result.value);",
		"    storeResult(result);",
		"    notifyResult(result.id);",
		"  }",
		"  return results.length;",
		"}",
	},
	{
		"class UserManager {",
		"  constructor(config) {",
		"    this.users = [];",
		"    this.config = config;",
		"  }",
		"  addUser(user) {",
		"    this.users.push(user);",
		"    this.notifyUser(user);",
		"  }",
		"  getUser(id) {",
		"    return this.users.find(u => u.id === id);",
		"  }",
		"}",
	},
	{
		"def calculate_metrics(metrics):",
		"    total = sum(metrics)",
		"    average = total / len(metrics)",
		"    for metric in metrics:",
		"        normalized = metric / total",
		"        print(f'Metric: {metric}')",
		"        process_metric(normalized)",
		"    return metrics",
	},
	{
		"const cache = new Cache();",
		"function getCachedData(key) {",
		"  const cached = cache.get(key);",
		"  if (cached) {",
		"    return cached;",
		"  }",
		"  const data = fetchData(key);",
		"  cache.set(key, data);",
		"  return data;",
		"}",
	},
	{
		"interface Request {",
		"  url: string;",
		"  method: string;",
		"  headers: Record<string, string>;",
		"}",
		"function sendRequest(request: Request) {",
		"  validateRequest(request);",
		"  const response = fetch(request.url);",
		"  logRequest(request);",
		"  return response;",
		"}",
	},
	{
		"let count = 0;",
		"function incrementCount() {",
		"  count++;",
		"  console.log('Count:', count);",
		"  if (count > 10) {",
		"    resetCount();",
		"  }",
		"  notifyCount(count);",
		"  return count;",
		"}",
	},
	{
		"const events = [];",
		"function handleEvent(event) {",
		"  events.push(event);",
		"  processEvent(event);",
		"  if (event.type === 'error') {",
		"    logEvent(event);",
		"    notifyError(event.message);",
		"  }",
		"  return events.length;",
		"}",
	},
}

--- Compute the minimum (optimal) moves to reach target.
--- For repeat search: 0 if already at target, otherwise 2 (search + n/N).
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end
	return 2 -- search + at least one n/N
end

--- Generate a new challenge: random snippet + random target + start position.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, start_pos}
function M.generate_challenge(buf, ns_id)
	-- Pick a random snippet from our custom pool
	local snippet = SNIPPETS[math.random(1, #SNIPPETS)]

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

	-- Pick a starting position at least 3 rows away from target
	local candidates = {}
	for _, pos in ipairs(valid_positions) do
		local row_dist = math.abs(pos.row - target.row)
		if row_dist >= 3 then
			candidates[#candidates + 1] = pos
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
		-- Pick a random candidate
		start_pos = candidates[math.random(1, #candidates)]
	end

	return {
		snippet_lines = snippet,
		target = target,
		start_pos = start_pos,
	}
end

return M
