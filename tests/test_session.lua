-- tests/test_session.lua
-- Direct lifecycle coverage for the session controller.

local buffer = require("vimteacher.buffer")
local highlight = require("vimteacher.highlight")
local key_blocking = require("vimteacher.key_blocking")
local lessons = require("vimteacher.lessons")
local session_mod = require("vimteacher.session")
local snippets = require("vimteacher.snippets")
local state_mod = require("vimteacher.state")
local stats = require("vimteacher.stats")

local assertions = require("helpers.assertions")
local counter = assertions.new_counter()
local assert_test = counter.assert_test

print("test_session: running...")

highlight.setup()
state_mod.reset()

local state = state_mod.session
state.source_window_line_numbers = {
	number = true,
	relativenumber = false,
	statuscolumn = "",
}
state.preferred_lesson_line_numbers = {
	number = true,
	relativenumber = true,
	statuscolumn = "",
}

local original = {
	buffer_create = buffer.create,
	buffer_render = buffer.render,
	buffer_render_menu = buffer.render_menu,
	buffer_render_completion = buffer.render_completion,
	buffer_get_snippet_bounds = buffer.get_snippet_bounds,
	buffer_apply_playing = buffer.apply_playing_line_numbers,
	buffer_apply_nonplaying = buffer.apply_nonplaying_line_numbers,
	buffer_restore = buffer.restore_line_numbers,
	lessons_get_sections = lessons.get_sections,
	lessons_get_lesson = lessons.get_lesson,
	key_blocking_block_insert = key_blocking.block_insert_keys,
	highlight_flash_success = highlight.flash_success,
	snippets_reset_recent = snippets.reset_recent,
	stats_record_session = stats.record_session,
	stats_save = stats.save,
	vim_defer_fn = vim.defer_fn,
}

local observed = {
	menu_setup = 0,
	clear_mode_keymaps = 0,
	clear_info_keymaps = 0,
	clear_playing_keymaps = 0,
	playing_keymaps = 0,
	completion_keymaps = 0,
	render_menu = 0,
	render_completion = nil,
	render_info = nil,
	render_current = 0,
	setup_autocmds = 0,
	block_insert = 0,
	reset_recent = 0,
	record_session = nil,
	save_called = false,
	restore_called = false,
}
local deferred_callbacks = {}

buffer.create = function()
	local buf = vim.api.nvim_create_buf(false, true)
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, buf)
	return buf, win
end

buffer.render_menu = function(bufnr)
	observed.render_menu = observed.render_menu + 1
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		"Select a Topic",
		"1. Test Lesson",
	})
	vim.api.nvim_buf_set_var(bufnr, "vimteacher_menu_row_to_lesson", { [2] = 1 })
	vim.api.nvim_buf_set_var(bufnr, "vimteacher_menu_row_to_col", { [2] = 0 })
end

buffer.render_completion = function(_bufnr, opts)
	observed.render_completion = vim.deepcopy(opts)
end

buffer.render = function(bufnr, opts)
	observed.render_info = vim.deepcopy(opts)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
		opts.title or "",
		(opts.snippet_lines and opts.snippet_lines[1]) or "",
	})
end

buffer.get_snippet_bounds = function()
	return 0, 1
end

buffer.apply_playing_line_numbers = function() end
buffer.apply_nonplaying_line_numbers = function() end
buffer.restore_line_numbers = function()
	observed.restore_called = true
end

lessons.get_sections = function()
	return {
		{
			title = "Getting Started",
			lessons = {
				{ name = "test_lesson", title = "Test Lesson" },
			},
		},
	}
end

local lesson = {
	title = "Test Lesson",
	description = { "desc" },
	hint_lines = { "hint" },
	challenges_required = 1,
	generate_challenge = function()
		return {
			snippet_lines = { "abc" },
			target = { row = 0, col = 1 },
			start_pos = { row = 0, col = 0 },
		}
	end,
	compute_optimal = function()
		return 7
	end,
}

local info_lesson = {
	title = "Info Lesson",
	description = { "info desc" },
	hint_lines = { "info hint" },
	type = "info",
	sandbox_snippet = { "sandbox" },
	generate_challenge = function()
		return {
			snippet_lines = { "sandbox" },
			target = { row = 0, col = 0 },
			start_pos = { row = 0, col = 0 },
		}
	end,
}

lessons.get_lesson = function(name)
	if name == "test_lesson" then
		return lesson
	end
	if name == "info_lesson" then
		return info_lesson
	end
	return nil
end

key_blocking.block_insert_keys = function()
	observed.block_insert = observed.block_insert + 1
end

highlight.flash_success = function() end

snippets.reset_recent = function()
	observed.reset_recent = observed.reset_recent + 1
end

stats.record_session = function(all_stats, lesson_name, total_time, accuracy)
	observed.record_session = {
		lesson_name = lesson_name,
		total_time = total_time,
		accuracy = accuracy,
	}
	all_stats[lesson_name] = {
		best_time = total_time,
		avg_time = total_time,
	}
	return all_stats[lesson_name]
end

stats.save = function()
	observed.save_called = true
end

vim.defer_fn = function(cb, _ms)
	deferred_callbacks[#deferred_callbacks + 1] = cb
	return #deferred_callbacks
end

local gameplay = {
	setup_autocmds = function()
		observed.setup_autocmds = observed.setup_autocmds + 1
	end,
	build_lesson_view = function(current_lesson)
		if current_lesson == info_lesson then
			return nil
		end
		return {
			title = current_lesson.title,
			description = current_lesson.description,
			hint_lines = current_lesson.hint_lines,
		}
	end,
	render_current_challenge = function()
		observed.render_current = observed.render_current + 1
		state.target = state.current_challenge.target
	end,
}

local mode_keymaps = {
	clear_mode_keymaps = function()
		observed.clear_mode_keymaps = observed.clear_mode_keymaps + 1
	end,
	clear_info_keymaps = function()
		observed.clear_info_keymaps = observed.clear_info_keymaps + 1
	end,
	clear_playing_keymaps = function()
		observed.clear_playing_keymaps = observed.clear_playing_keymaps + 1
	end,
	setup_playing_keymaps = function()
		observed.playing_keymaps = observed.playing_keymaps + 1
	end,
	setup_completion_keymaps = function()
		observed.completion_keymaps = observed.completion_keymaps + 1
	end,
}

local menu = {
	setup = function()
		observed.menu_setup = observed.menu_setup + 1
	end,
}

local controller = session_mod.new({
	state = state,
	gameplay = gameplay,
	mode_keymaps = mode_keymaps,
	menu = menu,
})

controller.show_menu()
assert_test(state.mode == "menu", "show_menu should switch the session into menu mode")
assert_test(observed.render_menu == 1, "show_menu should render the lesson menu")
assert_test(observed.menu_setup == 1, "show_menu should install menu keymaps")
assert_test(observed.block_insert == 1, "show_menu should block insert keys for the menu buffer")
assert_test(observed.setup_autocmds == 1, "show_menu should set up gameplay autocmds when creating the buffer")
local menu_cursor = vim.api.nvim_win_get_cursor(state.win)
assert_test(menu_cursor[1] == 2 and menu_cursor[2] == 0, "show_menu should move the cursor to the first lesson row")

controller.start("test_lesson")
assert_test(state.mode == "playing", "start should enter playing mode for a normal lesson")
assert_test(observed.clear_mode_keymaps == 1, "start should clear existing mode keymaps before rebinding")
assert_test(observed.reset_recent == 1, "start should reset lesson snippet recency")
assert_test(state.challenge_num == 1, "start should load the first challenge immediately")
assert_test(state.optimal_moves == 7, "start should compute the lesson's optimal move count")
assert_test(observed.render_current == 1, "start should render the active challenge")
assert_test(observed.playing_keymaps == 1, "start should install playing-mode keymaps")

state.move_count = 5
state.timer_start = vim.loop.hrtime() - 1e9
controller.advance_challenge()

assert_test(state.mode == "stats", "advance_challenge should enter stats mode before the deferred transition")
assert_test(#state.session_challenges == 1, "advance_challenge should record the completed challenge stats")
assert_test(type(deferred_callbacks[1]) == "function", "advance_challenge should schedule a deferred transition")
deferred_callbacks[1]()
assert_test(state.mode == "complete", "advance_challenge should reach the completion screen at the lesson boundary")
assert_test(
	observed.record_session ~= nil and observed.record_session.lesson_name == "test_lesson",
	"advance_challenge should record lesson session statistics"
)
assert_test(observed.save_called == true, "advance_challenge should persist updated stats")
assert_test(observed.render_completion ~= nil, "advance_challenge should render the completion screen")
assert_test(observed.completion_keymaps == 1, "advance_challenge should install completion keymaps")

observed.render_completion = nil
controller.show_menu()
controller.start("test_lesson")
state.move_count = 3
state.timer_start = vim.loop.hrtime() - 1e9
controller.advance_challenge()
assert_test(state.mode == "stats", "advance_challenge should still enter stats mode on a later run")
assert_test(
	type(deferred_callbacks[2]) == "function",
	"later challenge transitions should also schedule deferred callbacks"
)
controller.show_menu()
deferred_callbacks[2]()
assert_test(state.mode == "menu", "stale deferred callbacks should not override a later mode change")
assert_test(
	observed.render_completion == nil,
	"stale deferred callbacks should not render completion after leaving stats"
)

controller.start("info_lesson")
assert_test(state.mode == "info", "start should enter info mode for info lessons")
assert_test(observed.render_info ~= nil, "info lessons should still render when lesson_view is unavailable")
assert_test(observed.render_info.title == info_lesson.title, "info lesson fallback should use lesson title")
assert_test(
	observed.render_info.description[1] == info_lesson.description[1],
	"info lesson fallback should use lesson description"
)
assert_test(
	observed.render_info.snippet_lines[1] == info_lesson.sandbox_snippet[1],
	"info lesson fallback should use lesson sandbox snippet"
)

local old_buf = state.buf
controller.stop()
assert_test(observed.restore_called == true, "stop should restore the source window line number settings")
assert_test(not vim.api.nvim_buf_is_valid(old_buf), "stop should delete the session buffer")
assert_test(state.buf == nil and state.mode == "menu", "stop should reset the shared session state")

buffer.create = original.buffer_create
buffer.render = original.buffer_render
buffer.render_menu = original.buffer_render_menu
buffer.render_completion = original.buffer_render_completion
buffer.get_snippet_bounds = original.buffer_get_snippet_bounds
buffer.apply_playing_line_numbers = original.buffer_apply_playing
buffer.apply_nonplaying_line_numbers = original.buffer_apply_nonplaying
buffer.restore_line_numbers = original.buffer_restore
lessons.get_sections = original.lessons_get_sections
lessons.get_lesson = original.lessons_get_lesson
key_blocking.block_insert_keys = original.key_blocking_block_insert
highlight.flash_success = original.highlight_flash_success
snippets.reset_recent = original.snippets_reset_recent
stats.record_session = original.stats_record_session
stats.save = original.stats_save
vim.defer_fn = original.vim_defer_fn

counter.finish("test_session")
