-- vimteacher/lessons/quick_word_search.lua
-- Lesson: Quick word search with * and #

local base = require("vimteacher.lessons.base")

local M = base.define({
	title_template = "Word Search: {{*}}, {{#}}",
	template_tokens = {
		["*"] = "*",
		["#"] = "#",
		["/"] = "/",
		n = "n",
		N = "N",
	},
	dwell_time = 50,
	description_template = {
	"Search for a word instantly without typing it:",
	"",
	"  {{*}} = search FORWARD for the word under your cursor",
	"  {{#}} = search BACKWARD for the word under your cursor",
	"",
	"  Put your cursor on any word, then press {{*}} to jump to",
	"  the next time that word appears. Press {{#}} to go backward.",
	"",
	"  Much faster than typing {{/}}word every time!",
	"",
	"Navigate to the highlighted target word.",
	},
	hint_template = {
		"[{{*}}] Search word forward  [{{#}}] Search word backward  [{{n}}/{{N}}] Repeat",
	},
})

-- Custom snippets with repeated words for word search practice
-- Each snippet should be 6+ lines with words appearing multiple times
local SNIPPETS = {
	{
		"const count = 0;",
		"const items = getList();",
		"for (let i = 0; i < items.length; i++) {",
		"  count += items[i].value;",
		"}",
		"return count;",
	},
	{
		"function processData(data) {",
		"  if (!data) return null;",
		"  const result = transform(data);",
		"  console.log('Processing data');",
		"  validateData(data);",
		"  return result;",
		"}",
	},
	{
		"let error = null;",
		"try {",
		"  const value = parse(input);",
		"  if (value === null) {",
		"    error = new Error('Failed');",
		"  }",
		"} catch (e) {",
		"  error = e;",
		"}",
	},
	{
		"class Handler {",
		"  constructor(handler) {",
		"    this.handler = handler;",
		"    this.name = 'handler';",
		"  }",
		"  execute() {",
		"    return this.handler();",
		"  }",
		"}",
	},
	{
		"const config = loadConfig();",
		"if (config.debug) {",
		"  console.log('Config:', config);",
		"  saveConfig(config);",
		"}",
		"app.use(config.middleware);",
		"server.start(config.port);",
	},
	{
		"def process(data):",
		"    if not data:",
		"        return []",
		"    result = []",
		"    for item in data:",
		"        result.append(item)",
		"    return result",
	},
	{
		"public void update(State state) {",
		"    if (state == null) return;",
		"    this.state = state;",
		"    notifyListeners(state);",
		"    log('State updated');",
		"    saveState(state);",
		"}",
	},
	{
		"const user = getUser(id);",
		"if (!user) {",
		"  throw new Error('Not found');",
		"}",
		"user.lastLogin = Date.now();",
		"saveUser(user);",
		"return user;",
	},
	{
		"const request = buildRequest();",
		"if (!request.valid) {",
		"  logError('Invalid request');",
		"}",
		"const response = send(request);",
		"handleResponse(response);",
		"return response;",
	},
	{
		"let total = 0;",
		"for (const item of items) {",
		"  if (item.active) {",
		"    total += item.value;",
		"  }",
		"}",
		"logTotal(total);",
		"return total;",
	},
}

--- Compute the minimum (optimal) moves between two positions.
--- For word search with non-adjacent targets: * or # + at least one n/N.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	if start_pos.row == target.row and start_pos.col == target.col then
		return 0
	end
	return 2 -- * or # + at least one n/N
end

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

--- Generate a new challenge: snippet with repeated words.
--- Randomizes direction (* forward / # backward) and ensures non-adjacent targets.
--- @param buf number Buffer handle (unused)
--- @param ns_id number Namespace ID (unused)
--- @return table challenge {snippet_lines, target, target_end_col, start_pos, goal_text}
function M.generate_challenge(buf, ns_id)
	-- Pick a random snippet
	local snippet = SNIPPETS[math.random(1, #SNIPPETS)]

	-- Build a map of words to their positions (only alphanumeric words)
	local word_positions = {} -- word_positions[word] = list of {row, col}

	for row_idx, line in ipairs(snippet) do
		local col = 0
		while col < #line do
			local char = line:sub(col + 1, col + 1)
			if char:match("[%w_]") then
				local word = get_word_at_pos(line, col)
				if word and #word > 0 then
					if not word_positions[word] then
						word_positions[word] = {}
					end
					table.insert(word_positions[word], { row = row_idx - 1, col = col })
					-- Skip to end of word
					col = col + #word
				else
					col = col + 1
				end
			else
				col = col + 1
			end
		end
	end

	-- Find words that appear 2+ times
	local repeated_words = {}
	for word, positions in pairs(word_positions) do
		if #positions >= 2 then
			table.insert(repeated_words, { word = word, positions = positions })
		end
	end

	-- Safety: retry if no repeated words (shouldn't happen with our snippets)
	if #repeated_words == 0 then
		return M.generate_challenge(buf, ns_id)
	end

	-- Pick a random repeated word
	local chosen = repeated_words[math.random(1, #repeated_words)]
	local positions = chosen.positions

	-- Find ALL pairs (both directions: i→j and j→i) at least 3 rows apart
	local valid_pairs = {}
	for i = 1, #positions do
		for j = 1, #positions do
			if i ~= j then
				local row_dist = math.abs(positions[i].row - positions[j].row)
				if row_dist >= 3 then
					table.insert(valid_pairs, { start_idx = i, target_idx = j })
				end
			end
		end
	end

	-- If no pairs 3+ rows apart, try a different word or retry
	if #valid_pairs == 0 then
		return M.generate_challenge(buf, ns_id)
	end

	-- Prefer non-adjacent pairs (target is NOT the immediately next/prev occurrence)
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

	-- Pick a random valid pair
	local pair = selected_pairs[math.random(1, #selected_pairs)]
	local start_pos = positions[pair.start_idx]
	local target_pos = positions[pair.target_idx]

	-- Compute word length for full-word highlight
	local target_line = snippet[target_pos.row + 1]
	local target_word = get_word_at_pos(target_line, target_pos.col)
	local target_end_col = target_pos.col + (target_word and #target_word or 1)

	return {
		snippet_lines = snippet,
		target = { row = target_pos.row, col = target_pos.col },
		target_end_col = target_end_col,
		start_pos = { row = start_pos.row, col = start_pos.col },
		search_word = chosen.word,
		goal_text = "Use * or # to search for the word under cursor",
	}
end

return M
