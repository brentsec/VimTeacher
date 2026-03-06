-- tests/test_search_integration.lua
-- Runtime integration coverage for the Search section.

local vimteacher = require("vimteacher")
local search = require("vimteacher.lessons.search")
local repeat_search = require("vimteacher.lessons.repeat_search")
local quick_word_search = require("vimteacher.lessons.quick_word_search")
local search_review = require("vimteacher.lessons.search_review")
local search_replace = require("vimteacher.lessons.search_replace")
local assertions = require("helpers.assertions")
local integration = require("helpers.integration")

local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_search_integration: running...")

local remaps = integration.install_command_maps({
	{ canonical = "/", remap = "y" },
	{ canonical = "?", remap = "Y" },
	{ canonical = "n", remap = "m" },
	{ canonical = "N", remap = "M" },
	{ canonical = "*", remap = "8" },
	{ canonical = "#", remap = "3" },
	{ canonical = ":", remap = ";" },
})

integration.configure_adaptive(vimteacher)

local function assert_started(case)
	assert_test(integration.wait_for(function()
		return integration.buf_has_text("Challenge 1/10")
	end, 1000), case.lesson_name .. " should render challenge 1 for " .. case.label)
	for _, expected_ui in ipairs(case.expected_ui or {}) do
		assert_test(
			integration.buf_has_text(expected_ui),
			case.lesson_name .. " should render adaptive text '" .. expected_ui .. "' for " .. case.label
		)
	end
	assert_test(integration.snippet_matches(vimteacher, case.challenge.snippet_lines), case.lesson_name .. " should render deterministic snippet for " .. case.label)
	integration.prime_pending_cursor_event()
end

local function run_search_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vim.fn.setreg("/", "")
		vimteacher.start(case.lesson_name)
		assert_started(case)

		local snippet_row = integration.find_line_index(case.challenge.snippet_lines[1])
		assert_test(snippet_row ~= nil, case.lesson_name .. " should render the deterministic snippet for " .. case.label)
		if not snippet_row then
			return
		end

		local start_cursor = {
			snippet_row + case.challenge.start_pos.row,
			case.challenge.start_pos.col,
		}
		local cur0 = integration.current_cursor()
		assert_test(
			cur0[1] == start_cursor[1] and cur0[2] == start_cursor[2],
			case.lesson_name .. " should place cursor at deterministic start for " .. case.label
		)

		if case.blocked_key then
			integration.send_sequence(case.blocked_key)
			integration.wait_for(function()
				return true
			end, 60, 20)
			integration.fire_cursor_moved(0)
			local blocked = integration.current_cursor()
			assert_test(
				blocked[1] == start_cursor[1] and blocked[2] == start_cursor[2],
				"canonical " .. case.blocked_key .. " should remain blocked for " .. case.label
			)
		end

		for _, action in ipairs(case.actions) do
			if action.kind == "prompt" then
				integration.perform_prompt_sequence(action.key, action.text)
			else
				integration.send_sequence(action.key)
				integration.wait_for(function()
					return true
				end, 60, 20)
			end
			integration.fire_cursor_moved(0)
		end

		assert_test(integration.wait_for(function()
			local cur = integration.current_cursor()
			return cur[1] == (snippet_row + case.challenge.target.row) and cur[2] == case.challenge.target.col
		end, 500), case.lesson_name .. " should move to the expected target for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped command(s) for " .. case.label)
	end)
end

local function run_search_replace_case(case)
	integration.with_overridden_generate(case.module, case.challenge, function()
		vimteacher.start(case.lesson_name)
		assert_started(case)

		local before = integration.current_snippet_lines(vimteacher, #case.challenge.snippet_lines)

		integration.send_sequence(":")
		integration.wait_for(function()
			return true
		end, 60, 20)
		assert_test(
			integration.snippet_matches(vimteacher, before),
			"canonical : should remain blocked for " .. case.label
		)

		integration.perform_prompt_sequence(case.remap, case.command)
		integration.fire_text_changed(0)
		assert_test(integration.wait_for(function()
			return integration.snippet_matches(vimteacher, case.challenge.expected_lines)
		end, 600), case.lesson_name .. " should apply the expected substitution for " .. case.label)
		assert_test(integration.wait_for(function()
			return integration.buf_has_text("Challenge 2/10")
		end, 1800), case.lesson_name .. " should advance after remapped substitution for " .. case.label)
	end)
end

run_search_case({
	lesson_name = "search",
	module = search,
	label = "/ and n use remapped search keys",
	blocked_key = "/",
	expected_ui = {
		"Search: y, m, M",
		"[m] Next match",
		"[M] Previous match",
	},
	actions = {
		{ kind = "prompt", key = remaps.remap_for["/"], text = "data" },
		{ kind = "key", key = remaps.remap_for["n"] },
	},
	challenge = {
		snippet_lines = {
			"skip line;",
			"const data = fetch();",
			"return data;",
			"const next = data;",
		},
		target = { row = 2, col = 7 },
		target_end_col = 11,
		start_pos = { row = 1, col = 0 },
		search_word = "data",
		goal_text = "Search for 'data' and use n to reach the highlighted match.",
	},
})

run_search_case({
	lesson_name = "repeat_search",
	module = repeat_search,
	label = "N uses the remapped previous-match key",
	blocked_key = "N",
	expected_ui = {
		"Repeat Search: m, M",
		"[m] Next match",
		"[M] Previous match",
	},
	actions = {
		{ kind = "prompt", key = remaps.remap_for["/"], text = "return" },
		{ kind = "key", key = remaps.remap_for["N"] },
	},
	challenge = {
		snippet_lines = {
			"return a;",
			"noop();",
			"return b;",
			"noop();",
			"return c;",
		},
		target = { row = 0, col = 0 },
		start_pos = { row = 4, col = 1 },
	},
})

run_search_case({
	lesson_name = "quick_word_search",
	module = quick_word_search,
	label = "* uses the remapped word-search key",
	blocked_key = "*",
	expected_ui = {
		"Word Search: 8, 3",
		"[8] Search word forward",
		"[3] Search word backward",
	},
	actions = {
		{ kind = "key", key = remaps.remap_for["*"] },
	},
	challenge = {
		snippet_lines = {
			"const count = 0;",
			"log(count);",
			"return count;",
		},
		target = { row = 1, col = 4 },
		target_end_col = 9,
		start_pos = { row = 0, col = 6 },
		goal_text = "Use * to jump to the next highlighted word.",
	},
})

run_search_case({
	lesson_name = "search_review",
	module = search_review,
	label = "# uses the remapped backward word-search key",
	blocked_key = "#",
	expected_ui = {
		"[8/3] Word search",
	},
	actions = {
		{ kind = "key", key = remaps.remap_for["#"] },
	},
	challenge = {
		snippet_lines = {
			"const user = getUser();",
			"if (!user) return nil;",
			"saveUser(user);",
			"return user;",
		},
		target = { row = 2, col = 9 },
		start_pos = { row = 3, col = 7 },
	},
})

do
	local all = search_replace._get_challenges()
	local challenge = vim.deepcopy(all[3])
	run_search_replace_case({
		lesson_name = "search_replace",
		module = search_replace,
		label = ": substitution uses the remapped command-line key",
		remap = remaps.remap_for[":"],
		command = "%s/usr/user/g",
		expected_ui = {
			"Search & Replace: ;s, ;%s",
			"[;s] Current line",
			"[;%s] Whole file",
		},
		challenge = challenge,
	})
end

integration.clear_maps(remaps.cleanup_keys)
counter.finish("test_search_integration")
