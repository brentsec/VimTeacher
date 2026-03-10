-- vimteacher/lessons/delete_inside_brackets.lua
-- Lesson: Delete inside brackets with di(, di[, di{

local bracket_text_objects = require("vimteacher.lessons.bracket_text_objects")

-- Pre-defined challenge pool.
-- Each challenge targets a specific bracket pair on a line.
-- target.col should be positioned somewhere inside the brackets.
local CHALLENGES = {
	-- Challenge 1: di( — clear function call arguments
	{
		snippet_lines = {
			"function initialize(config) {",
			"  console.log(data.name);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function initialize(config) {",
			"  console.log();",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 17 },
		start_pos = { row = 3, col = 0 },
		key = "di(",
	},

	-- Challenge 2: di[ — clear array contents
	{
		snippet_lines = {
			"function getData() {",
			"  const items = [1, 2, 3, 4];",
			"  return items;",
			"}",
		},
		expected_lines = {
			"function getData() {",
			"  const items = [];",
			"  return items;",
			"}",
		},
		target = { row = 1, col = 19 },
		start_pos = { row = 0, col = 0 },
		key = "di[",
	},

	-- Challenge 3: di{ — clear object contents
	{
		snippet_lines = {
			"function createUser() {",
			"  const user = { name: 'John', age: 30 };",
			"  return user;",
			"}",
		},
		expected_lines = {
			"function createUser() {",
			"  const user = {};",
			"  return user;",
			"}",
		},
		target = { row = 1, col = 20 },
		start_pos = { row = 3, col = 0 },
		key = "di{",
	},

	-- Challenge 4: di( — clear nested function call
	{
		snippet_lines = {
			"function process() {",
			"  const result = parseInt(value);",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function process() {",
			"  const result = parseInt();",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 28 },
		start_pos = { row = 0, col = 0 },
		key = "di(",
	},

	-- Challenge 5: di[ — clear array index access
	{
		snippet_lines = {
			"function getFirst(arr) {",
			"  const first = arr[0];",
			"  return first;",
			"}",
		},
		expected_lines = {
			"function getFirst(arr) {",
			"  const first = arr[];",
			"  return first;",
			"}",
		},
		target = { row = 1, col = 21 },
		start_pos = { row = 3, col = 0 },
		key = "di[",
	},

	-- Challenge 6: di{ — clear inline object
	{
		snippet_lines = {
			"function config() {",
			"  return { port: 3000, host: 'localhost' };",
			"}",
		},
		expected_lines = {
			"function config() {",
			"  return {};",
			"}",
		},
		target = { row = 1, col = 15 },
		start_pos = { row = 0, col = 0 },
		key = "di{",
	},

	-- Challenge 7: di( — clear method call arguments
	{
		snippet_lines = {
			"function update(data) {",
			"  obj.method(arg1, arg2, arg3);",
			"  return true;",
			"}",
		},
		expected_lines = {
			"function update(data) {",
			"  obj.method();",
			"  return true;",
			"}",
		},
		target = { row = 1, col = 18 },
		start_pos = { row = 3, col = 0 },
		key = "di(",
	},

	-- Challenge 8: di[ — clear array literal
	{
		snippet_lines = {
			"function getColors() {",
			"  const colors = ['red', 'green', 'blue'];",
			"  return colors;",
			"}",
		},
		expected_lines = {
			"function getColors() {",
			"  const colors = [];",
			"  return colors;",
			"}",
		},
		target = { row = 1, col = 25 },
		start_pos = { row = 0, col = 0 },
		key = "di[",
	},

	-- Challenge 9: di{ — clear template object
	{
		snippet_lines = {
			"function template() {",
			"  const obj = { id: 1, status: 'active' };",
			"  return obj;",
			"}",
		},
		expected_lines = {
			"function template() {",
			"  const obj = {};",
			"  return obj;",
			"}",
		},
		target = { row = 1, col = 23 },
		start_pos = { row = 3, col = 0 },
		key = "di{",
	},

	-- Challenge 10: di( — clear constructor arguments
	{
		snippet_lines = {
			"function create() {",
			"  const instance = new MyClass(param1, param2);",
			"  return instance;",
			"}",
		},
		expected_lines = {
			"function create() {",
			"  const instance = new MyClass();",
			"  return instance;",
			"}",
		},
		target = { row = 1, col = 35 },
		start_pos = { row = 0, col = 0 },
		key = "di(",
	},
}

local M = bracket_text_objects.define({
	lesson = {
		title_template = "Delete Inside: {{di_paren}}, {{di_bracket}}, {{di_brace}}",
		type = "insert",
		allowed_keys = {},
		allowed_modify_keys = { "d" },
		challenges_required = 10,
		template_tokens = {
			di_paren = "di(",
			di_bracket = "di[",
			di_brace = "di{",
		},
		description_template = {
			"Delete text inside brackets without removing the brackets:",
			"",
			"  {{di_paren}}  = delete inside parentheses",
			"  {{di_bracket}}  = delete inside square brackets",
			"  {{di_brace}}  = delete inside curly braces",
			"",
			"Place cursor anywhere inside the brackets and execute the command.",
			"The brackets remain, but their contents are deleted.",
		},
		hint_template = {
			"[{{di_paren}}] Delete inside ()  [{{di_bracket}}] Delete inside []  [{{di_brace}}] Delete inside {}",
		},
	},
	challenges = CHALLENGES,
	optimal_offset = 1,
})

return M
