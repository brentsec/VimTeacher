-- vimteacher/lessons/search_replace.lua
-- Lesson: Search and replace with :s, :%s, ranges, and g flag

local M = {}
local pool = require("vimteacher.lessons.pool")

M.title = "Search & Replace: :s, :%s"
M.type = "insert"
-- Ex substitution lives in the command-line, so this lesson intentionally
-- keeps normal-mode editing keys available while the command is being typed.
M.allowed_keys = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
M.allowed_modify_keys = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
M.allowed_visual_keys = { "v", "V", "<C-v>" }
M.challenges_required = 10

M.description = {
	"Use Ex substitution commands to refactor text quickly:",
	"",
	"  :s/old/new/        replace first match on current line",
	"  :s/old/new/g       replace ALL matches on current line",
	"  :%s/old/new/g      replace across the whole file",
	"  :.,+1s/old/new/g   replace on current line + next line",
	"",
	"Move to the green target and run a substitution command.",
}

M.hint_lines = {
	"[:s] Current line  [:%s] Whole file  [g] Global matches  [range] :.,+1s/old/new/g",
}

local CHALLENGES = {
	{
		snippet_lines = {
			"function greet() {",
			"  const mesage = 'hi';",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function greet() {",
			"  const message = 'hi';",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 8 },
		target_end_col = 14,
		start_pos = { row = 0, col = 0 },
		goal_text = "Use :s/mesage/message/ on this line",
	},
	{
		snippet_lines = {
			"function totals() {",
			"  const value = value + value;",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function totals() {",
			"  const amount = amount + amount;",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 8 },
		target_end_col = 13,
		start_pos = { row = 0, col = 0 },
		goal_text = "Use :s/value/amount/g on this line",
	},
	{
		snippet_lines = {
			"function findUser(id) {",
			"  const usr = getUser(id);",
			"  if (!usr) return null;",
			"  return usr.name;",
			"}",
		},
		expected_lines = {
			"function findUser(id) {",
			"  const user = getUser(id);",
			"  if (!user) return null;",
			"  return user.name;",
			"}",
		},
		target = { row = 1, col = 8 },
		target_end_col = 11,
		start_pos = { row = 1, col = 8 },
		goal_text = "Use :%s/usr/user/g for whole file",
	},
	{
		snippet_lines = {
			"function applyConfig() {",
			"  cfg.timeout = 30;",
			"  cfg.retries = 3;",
			"  return cfg.timeout + cfg.retries;",
			"}",
		},
		expected_lines = {
			"function applyConfig() {",
			"  config.timeout = 30;",
			"  config.retries = 3;",
			"  return config.timeout + config.retries;",
			"}",
		},
		target = { row = 1, col = 2 },
		target_end_col = 5,
		start_pos = { row = 1, col = 2 },
		goal_text = "Use :%s/cfg/config/g for whole file",
	},
	{
		snippet_lines = {
			"const api_url = buildUrl();",
			"return fetch(api_url);",
		},
		expected_lines = {
			"const endpoint_url = buildUrl();",
			"return fetch(endpoint_url);",
		},
		target = { row = 0, col = 6 },
		target_end_col = 13,
		start_pos = { row = 0, col = 6 },
		goal_text = "Use :%s/api_url/endpoint_url/g for whole file",
	},
	{
		snippet_lines = {
			"function finish() {",
			"  const temp = compute(temp_value);",
			"  log(temp);",
			"  return temp;",
			"}",
		},
		expected_lines = {
			"function finish() {",
			"  const result = compute(temp_value);",
			"  log(result);",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 8 },
		target_end_col = 12,
		start_pos = { row = 1, col = 8 },
		goal_text = "Use :%s/\\<temp\\>/result/g (whole-word match)",
	},
	{
		snippet_lines = {
			"function lookup(id) {",
			"  const data = dataMap.get(id);",
			"  return dataMap;",
			"}",
		},
		expected_lines = {
			"function lookup(id) {",
			"  const item = dataMap.get(id);",
			"  return dataMap;",
			"}",
		},
		target = { row = 1, col = 8 },
		target_end_col = 12,
		start_pos = { row = 0, col = 0 },
		goal_text = "Use :s/data/item/ (first match only)",
	},
	{
		snippet_lines = {
			"const label = 'title';",
			"let status = 'draft';",
			"if (status == 'draft') notify(status);",
			"return status;",
		},
		expected_lines = {
			"const label = 'title';",
			"let status = 'ready';",
			"if (status == 'ready') notify(status);",
			"return status;",
		},
		target = { row = 1, col = 16 },
		target_end_col = 21,
		start_pos = { row = 1, col = 16 },
		goal_text = "From target line, use :.,+1s/draft/ready/g (range + global)",
	},
	{
		snippet_lines = {
			"function endpoint() {",
			"  const path = '/api/v1/api';",
			"  return path;",
			"}",
		},
		expected_lines = {
			"function endpoint() {",
			"  const path = '/service/v1/service';",
			"  return path;",
			"}",
		},
		target = { row = 1, col = 17 },
		target_end_col = 20,
		start_pos = { row = 0, col = 0 },
		goal_text = "Use :s/api/service/g on this line",
	},
	{
		snippet_lines = {
			"errorCount = getErrorCount();",
			"if (errorCount > 0) logError(errorCount);",
			"return errorCount;",
		},
		expected_lines = {
			"issueCount = getErrorCount();",
			"if (issueCount > 0) logError(issueCount);",
			"return issueCount;",
		},
		target = { row = 0, col = 0 },
		target_end_col = 10,
		start_pos = { row = 0, col = 0 },
		goal_text = "Use :%s/errorCount/issueCount/g for whole file",
	},
}

local challenge_pool = pool.new(CHALLENGES)

--- Compute the minimum (optimal) moves between two positions.
--- Uses motion-aware shortest-path scoring on the current snippet.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
M.compute_optimal = challenge_pool.nav_compute_optimal()
M.generate_challenge = challenge_pool.generate_challenge
M._get_challenges = challenge_pool.get_challenges

return M
