-- vimteacher/lessons/search.lua
-- Search lesson: /, ?, n, N (merged with repeat_search)

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Search: {{/}}, {{n}}, {{N}}",
	template_tokens = {
		["/"] = "/",
		["?"] = "?",
		n = "n",
		N = "N",
	},
	dwell_time = 50,
	description_template = {
		"Search for text and cycle through matches:",
		"",
		"  {{/}}word  = search FORWARD for 'word' (type {{/}}, then the word, then Enter)",
		"  {{?}}word  = search BACKWARD (type {{?}}, then the word, then Enter)",
		"  {{n}}      = jump to the NEXT match (same direction as your search)",
		"  {{N}}      = jump to the PREVIOUS match (opposite direction)",
		"",
		"Search for the highlighted word, then use {{n}}/{{N}} to reach the exact match.",
	},
	hint_template = {
		"[{{/}}word Enter] Search  [{{n}}] Next match  [{{N}}] Previous match  [{{?}}word] Backward",
	},
})

-- Custom snippets with deliberately repeated keywords for search practice
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

--- Extract word at a given position in a line.
--- A word is a sequence of alphanumeric characters and underscores.
--- @param line string The line text
--- @param col number 0-indexed column position
--- @return string|nil The word at the position, or nil if not on a word
local function get_word_at_pos(line, col)
	if col < 0 or col >= #line then
		return nil
	end

	local char = line:sub(col + 1, col + 1)
	if not char:match("[%w_]") then
		return nil
	end

	-- Find start of word
	local start_col = col
	while start_col > 0 do
		local prev_char = line:sub(start_col, start_col)
		if not prev_char:match("[%w_]") then
			break
		end
		start_col = start_col - 1
	end

	-- Find end of word
	local end_col = col + 1
	while end_col <= #line do
		local next_char = line:sub(end_col + 1, end_col + 1)
		if not next_char:match("[%w_]") then
			break
		end
		end_col = end_col + 1
	end

	return line:sub(start_col + 1, end_col)
end

--- Compute the minimum (optimal) moves between two positions.
--- For search + repeat: search (1) + at least one n/N (1) = 2.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end
	return 2 -- search + at least one n/N
end

--- Generate a new challenge: snippet with repeated words, target a specific occurrence.
--- @param buf number Buffer handle (unused for this lesson, but part of interface)
--- @param ns_id number Namespace ID (unused for this lesson)
--- @return table challenge {snippet_lines, target, target_end_col, start_pos, search_word, goal_text}
function M.generate_challenge()
	local snippet = SNIPPETS[math.random(1, #SNIPPETS)]

	-- Build word->positions map
	local word_positions = {}
	for row_idx, line in ipairs(snippet) do
		local col = 0
		while col < #line do
			local char = line:sub(col + 1, col + 1)
			if char:match("[%w_]") then
				local word = get_word_at_pos(line, col)
				if word and #word >= 2 then
					if not word_positions[word] then
						word_positions[word] = {}
					end
					table.insert(word_positions[word], {
						row = row_idx - 1,
						col = col,
						end_col = col + #word,
					})
					col = col + #word
				else
					col = col + 1
				end
			else
				col = col + 1
			end
		end
	end

	-- Find words with 3+ occurrences (ensures n/N is needed)
	local repeated = {}
	for word, positions in pairs(word_positions) do
		if #positions >= 3 then
			table.insert(repeated, { word = word, positions = positions })
		end
	end

	-- Fallback to 2+ occurrences
	if #repeated == 0 then
		for word, positions in pairs(word_positions) do
			if #positions >= 2 then
				table.insert(repeated, { word = word, positions = positions })
			end
		end
	end

	-- Safety: retry with different snippet if no repeated words
	if #repeated == 0 then
		return M.generate_challenge()
	end

	local chosen = repeated[math.random(1, #repeated)]
	local positions = chosen.positions

	-- Pick start and target: ensure they are at least 3 rows apart.
	-- For words with 3+ occurrences, prefer target that is NOT the first match
	-- after start (forces n/N usage).
	local valid_pairs = {}
	for i = 1, #positions do
		for j = 1, #positions do
			if i ~= j then
				local row_dist = math.abs(positions[i].row - positions[j].row)
				if row_dist >= 3 then
					valid_pairs[#valid_pairs + 1] = { start_idx = i, target_idx = j }
				end
			end
		end
	end

	-- If no pairs 3+ rows apart, retry
	if #valid_pairs == 0 then
		return M.generate_challenge()
	end

	-- Prefer pairs where target is NOT the immediately next occurrence (forces n/N)
	local non_adjacent = {}
	for _, pair in ipairs(valid_pairs) do
		local si, ti = pair.start_idx, pair.target_idx
		if si < ti and ti > si + 1 then
			non_adjacent[#non_adjacent + 1] = pair
		elseif si > ti and ti < si - 1 then
			non_adjacent[#non_adjacent + 1] = pair
		end
	end

	local selected_pairs = #non_adjacent > 0 and non_adjacent or valid_pairs
	local pair = selected_pairs[math.random(1, #selected_pairs)]

	local start_pos = positions[pair.start_idx]
	local target_pos = positions[pair.target_idx]

	return {
		snippet_lines = snippet,
		target = { row = target_pos.row, col = target_pos.col },
		target_end_col = target_pos.end_col,
		start_pos = { row = start_pos.row, col = start_pos.col },
		search_word = chosen.word,
		goal_text = "Search for a word, then use n/N to reach the target",
	}
end

return M
