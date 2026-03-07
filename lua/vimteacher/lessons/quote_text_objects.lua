-- vimteacher/lessons/quote_text_objects.lua
-- Quote text objects: di", da", ci", ca" (and single quote variants)

local base = require("vimteacher.lessons.base")
local pool = require("vimteacher.lessons.pool")

local M = base.define({
	title_template = "Quote Objects: {{di_quote}}, {{ci_quote}}, {{da_quote}}, {{ca_quote}}",
	type = "insert",
	allowed_keys = { "c" },
	allowed_modify_keys = { "d" },
	challenges_required = 10,
	template_tokens = {
		di_quote = 'di"',
		da_quote = 'da"',
		ci_quote = 'ci"',
		ca_quote = 'ca"',
		di_squote = "di'",
		da_squote = "da'",
		ci_squote = "ci'",
		ca_squote = "ca'",
	},
	description_template = {
		"Act on text inside or around quotation marks:",
		"",
		'  {{di_quote}} = delete inside double quotes: "hello" becomes ""',
		"  {{da_quote}} = delete around double quotes: removes quotes too",
		"  {{ci_quote}} = change inside quotes: clears content, type replacement",
		"  {{ca_quote}} = change around quotes: removes quotes, type replacement",
		"",
		"  Same keys work with single quotes: {{di_squote}} {{da_squote}} {{ci_squote}} {{ca_squote}}",
		"",
		"Navigate inside the quotes and use the indicated command.",
	},
	hint_template = {
		"[{{di_quote}}] Del inside  [{{da_quote}}] Del around  [{{ci_quote}}] Change inside  [{{ca_quote}}] Change around",
	},
})

-- Pre-defined challenge pool.
-- di": delete inside quotes (keep quotes)
-- da": delete around quotes (remove quotes + contents)
-- ci": change inside quotes (replace contents with char, keep quotes)
-- ca": change around quotes (replace quotes + contents with char)
local CHALLENGES = {
	-- Challenge 1: di" — delete inside double quotes
	{
		snippet_lines = {
			"function greet() {",
			'  const name = "oldname";',
			"  return name;",
			"}",
		},
		expected_lines = {
			"function greet() {",
			'  const name = "";',
			"  return name;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 3, col = 0 },
		key = 'di"',
		char = "",
	},

	-- Challenge 2: da" — delete around double quotes
	{
		snippet_lines = {
			"function debug() {",
			'  log("debug msg");',
			"  return true;",
			"}",
		},
		expected_lines = {
			"function debug() {",
			"  log();",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = 'da"',
		char = "",
	},

	-- Challenge 3: ci" — change inside double quotes
	{
		snippet_lines = {
			"function fetch() {",
			'  const url = "http://old.com";',
			"  return fetch(url);",
			"}",
		},
		expected_lines = {
			"function fetch() {",
			'  const url = "http://new.com";',
			"  return fetch(url);",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 3, col = 0 },
		key = 'ci"',
		char = "http://new.com",
	},

	-- Challenge 4: ci' — change inside single quotes
	{
		snippet_lines = {
			"function getChar() {",
			"  const ch = 'x';",
			"  return ch;",
			"}",
		},
		expected_lines = {
			"function getChar() {",
			"  const ch = 'y';",
			"  return ch;",
			"}",
		},
		target = { row = 1, col = 14 },
		start_pos = { row = 0, col = 0 },
		key = "ci'",
		char = "y",
	},

	-- Challenge 5: di' — delete inside single quotes
	{
		snippet_lines = {
			"function setTag() {",
			"  tag = 'obsolete';",
			"  return tag;",
			"}",
		},
		expected_lines = {
			"function setTag() {",
			"  tag = '';",
			"  return tag;",
			"}",
		},
		target = { row = 1, col = 10 },
		start_pos = { row = 3, col = 0 },
		key = "di'",
		char = "",
	},

	-- Challenge 6: da' — delete around single quotes
	{
		snippet_lines = {
			"function process() {",
			"  const status = 'active';",
			"  return check(status);",
			"}",
		},
		expected_lines = {
			"function process() {",
			"  const status = ;",
			"  return check(status);",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 0, col = 0 },
		key = "da'",
		char = "",
	},

	-- Challenge 7: ci" — change string value
	{
		snippet_lines = {
			"function config() {",
			'  const mode = "development";',
			"  return mode;",
			"}",
		},
		expected_lines = {
			"function config() {",
			'  const mode = "production";',
			"  return mode;",
			"}",
		},
		target = { row = 1, col = 20 },
		start_pos = { row = 3, col = 0 },
		key = 'ci"',
		char = "production",
	},

	-- Challenge 8: da" — remove a quoted argument
	{
		snippet_lines = {
			"function warn() {",
			'  console.warn("warning");',
			"  return false;",
			"}",
		},
		expected_lines = {
			"function warn() {",
			"  console.warn();",
			"  return false;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 0, col = 0 },
		key = 'da"',
		char = "",
	},

	-- Challenge 9: ci' — change a character literal
	{
		snippet_lines = {
			"function getDelimiter() {",
			"  const delim = ',';",
			"  return delim;",
			"}",
		},
		expected_lines = {
			"function getDelimiter() {",
			"  const delim = ';';",
			"  return delim;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 3, col = 0 },
		key = "ci'",
		char = ";",
	},

	-- Challenge 10: di" — empty a string constant
	{
		snippet_lines = {
			"function init() {",
			'  const empty = "placeholder";',
			"  return empty;",
			"}",
		},
		expected_lines = {
			"function init() {",
			'  const empty = "";',
			"  return empty;",
			"}",
		},
		target = { row = 1, col = 20 },
		start_pos = { row = 0, col = 0 },
		key = 'di"',
		char = "",
	},
}

local challenge_pool = pool.new(CHALLENGES)

--- Compute the minimum (optimal) moves between two positions.
--- Uses motion-aware shortest-path scoring on the current snippet.
--- @param start_pos table {row=number, col=number} 0-indexed
--- @param target table {row=number, col=number} 0-indexed
--- @return number Optimal move count
function M.compute_optimal(start_pos, target)
	return challenge_pool.nav_compute_optimal()(start_pos, target) + 1
end
M.generate_challenge = challenge_pool.generate_challenge
M._get_challenges = challenge_pool.get_challenges

return M
