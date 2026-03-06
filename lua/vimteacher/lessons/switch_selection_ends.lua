-- vimteacher/lessons/switch_selection_ends.lua
-- Lesson: Switch active visual selection end with 'o'

local base = require("vimteacher.lessons.base")
local pool = require("vimteacher.lessons.pool")

local M = base.define({
	title_template = "Switch Selection Ends: {{o}}",
	type = "insert",
	allowed_keys = { "o" },
	allowed_modify_keys = { "d" },
	allowed_visual_keys = { "v" },
	challenges_required = 10,
	template_tokens = {
		o = "o",
		v = "v",
		d = "d",
		Esc = "Esc",
	},
	description_template = {
	"In Visual mode, '{{o}}' swaps your cursor to the OTHER end of the selection.",
	"",
	"Why this matters: after selecting text, you can jump to the far end and",
	"fine-tune the opposite side without cancelling your selection.",
	"",
	"Challenge flow:",
	"  1. Move to green target",
	"  2. Press {{v}} and select text",
	"  3. Press {{o}} to switch ends",
	"  4. Adjust selection and press {{d}}",
	},
	hint_template = {
		"[{{v}}] Visual mode  [{{o}}] Switch selection end  [{{d}}] Delete selection  [{{Esc}}] Cancel selection",
	},
})

-- Pre-defined challenge pool.
-- Delete the highlighted span using visual mode; 'o' helps adjust the far end.
local CHALLENGES = {
	{
		snippet_lines = {
			"function process() {",
			"  const bad_value = 5;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function process() {",
			"  const value = 5;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 11 },
		select_end = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function init() {",
			"  const extra value = 42;",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function init() {",
			"  const value = 42;",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 13 },
		select_end = { row = 1, col = 8 },
		start_pos = { row = 3, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function cfg() {",
			"  const ba_mode = debug;",
			"  return bad_mode;",
			"}",
		},
		expected_lines = {
			"function cfg() {",
			"  const mode = debug;",
			"  return bad_mode;",
			"}",
		},
		target = { row = 1, col = 10 },
		select_end = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function labels() {",
			"  const a = alpha000; const b = beta000;",
			"  return a + b;",
			"}",
		},
		expected_lines = {
			"function labels() {",
			"  const a = alpha; const b = beta000;",
			"  return a + b;",
			"}",
		},
		target = { row = 1, col = 19 },
		select_end = { row = 1, col = 17 },
		start_pos = { row = 3, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function clean() {",
			"  let unused_var = 1;",
			"  return var;",
			"}",
		},
		expected_lines = {
			"function clean() {",
			"  let var = 1;",
			"  return var;",
			"}",
		},
		target = { row = 1, col = 12 },
		select_end = { row = 1, col = 6 },
		start_pos = { row = 3, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function run() {",
			"  const wrong_name = getName();",
			"  return name;",
			"}",
		},
		expected_lines = {
			"function run() {",
			"  const name = getName();",
			"  return name;",
			"}",
		},
		target = { row = 1, col = 13 },
		select_end = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function normalize() {",
			"  const old_value = parse();",
			"  return value;",
			"}",
		},
		expected_lines = {
			"function normalize() {",
			"  const value = parse();",
			"  return value;",
			"}",
		},
		target = { row = 1, col = 11 },
		select_end = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function render() {",
			"  const prefix_label = getTag();",
			"  return label;",
			"}",
		},
		expected_lines = {
			"function render() {",
			"  const label = getTag();",
			"  return label;",
			"}",
		},
		target = { row = 1, col = 14 },
		select_end = { row = 1, col = 8 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function parse() {",
			"  const item_temp = list[0];",
			"  return item;",
			"}",
		},
		expected_lines = {
			"function parse() {",
			"  const item = list[0];",
			"  return item;",
			"}",
		},
		target = { row = 1, col = 16 },
		select_end = { row = 1, col = 12 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
		char = "",
	},
	{
		snippet_lines = {
			"function api() {",
			"  const result = server_url + '/users';",
			"  return result;",
			"}",
		},
		expected_lines = {
			"function api() {",
			"  const result = url + '/users';",
			"  return result;",
			"}",
		},
		target = { row = 1, col = 23 },
		select_end = { row = 1, col = 17 },
		start_pos = { row = 0, col = 0 },
		key = "vod",
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
	return challenge_pool.nav_compute_optimal()(start_pos, target)
end
M.generate_challenge = challenge_pool.generate_challenge
M._get_challenges = challenge_pool.get_challenges

return M
