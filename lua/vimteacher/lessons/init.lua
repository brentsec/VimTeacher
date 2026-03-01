-- vimteacher/lessons/init.lua
-- Lesson registry, loader, and interface validation

local M = {}

-- Ordered sections with their lessons (add new sections/lessons here)
M.sections = {
	{
		title = "Getting Started",
		lessons = { "intro_modes", "basic_movement", "word_movement", "insert_mode" },
	},
	{
		title = "Advanced Inserts",
		lessons = { "line_inserts", "open_lines", "small_edits" },
	},
	{
		title = "Essential Motions",
		lessons = { "upper_word_movement", "line_ends", "find_char", "till_char" },
	},
	{
		title = "Basic Operators",
		lessons = {
			"intro_operators",
			"delete_words",
			"change_words",
			"delete_lines",
			"delete_multiple_lines",
			"copy_paste_lines",
		},
	},
	{
		title = "Advanced Vertical Movement",
		lessons = { "relative_line_jumps", "absolute_line_jumps", "paragraph_jumps", "window_scrolls" },
	},
	{
		title = "Search",
		lessons = { "search", "quick_word_search", "search_review" },
	},
	{
		title = "Text Objects: Brackets",
		lessons = {
			"intro_text_objects",
			"delete_inside_brackets",
			"delete_around_brackets",
			"change_inside_brackets",
			"change_around_brackets",
		},
	},
	{
		title = "Text Objects: Quotes, Words & Paragraphs",
		lessons = {
			"quote_text_objects",
			"word_text_objects",
			"paragraph_text_objects",
			"text_objects_mega_review",
		},
	},
	{
		title = "Editing Efficiency",
		lessons = { "repeat_power" },
	},
	{
		title = "Visual Mode",
		lessons = {
			"intro_visual_mode",
			"visual_mode_operators",
			"visual_line_mode",
			"switch_selection_ends",
		},
	},
}

-- Derived flat order (for navigation: get_next, get_prev, get_all)
M.order = {}
for _, section in ipairs(M.sections) do
	for _, name in ipairs(section.lessons) do
		M.order[#M.order + 1] = name
	end
end

-- Cache of loaded lesson modules
local loaded = {}

-- Required fields every lesson must have
local REQUIRED_FIELDS = { "title", "description", "hint_lines", "generate_challenge" }

--- Validate a lesson module has all required fields.
--- @param name string Lesson name
--- @param mod table Lesson module
--- @return boolean valid
local function validate_lesson(name, mod)
	for _, field in ipairs(REQUIRED_FIELDS) do
		if mod[field] == nil then
			vim.notify("VimTeacher: Lesson '" .. name .. "' missing required field: " .. field, vim.log.levels.ERROR)
			return false
		end
	end
	if type(mod.generate_challenge) ~= "function" then
		vim.notify("VimTeacher: Lesson '" .. name .. "': generate_challenge must be a function", vim.log.levels.ERROR)
		return false
	end
	if type(mod.description) ~= "table" then
		vim.notify("VimTeacher: Lesson '" .. name .. "': description must be a table of strings", vim.log.levels.ERROR)
		return false
	end
	return true
end

--- Get a lesson module by name. Loads and validates on first access.
--- @param name string Lesson name (e.g., "basic_movement")
--- @return table|nil Lesson module or nil if invalid
function M.get_lesson(name)
	if loaded[name] then
		return loaded[name]
	end

	local ok, mod = pcall(require, "vimteacher.lessons." .. name)
	if not ok then
		vim.notify("VimTeacher: Failed to load lesson '" .. name .. "': " .. tostring(mod), vim.log.levels.ERROR)
		return nil
	end

	if not validate_lesson(name, mod) then
		return nil
	end

	loaded[name] = mod
	return mod
end

--- Get the next lesson name in the ordered list.
--- @param current_name string Current lesson name
--- @return string|nil Next lesson name, or nil if at the end
function M.get_next(current_name)
	for i, name in ipairs(M.order) do
		if name == current_name and i < #M.order then
			return M.order[i + 1]
		end
	end
	return nil
end

--- Get the previous lesson name in the ordered list.
--- @param current_name string Current lesson name
--- @return string|nil Previous lesson name, or nil if at the start
function M.get_prev(current_name)
	for i, name in ipairs(M.order) do
		if name == current_name and i > 1 then
			return M.order[i - 1]
		end
	end
	return nil
end

--- Get all lessons as ordered list of {name, title} for the menu.
--- @return table[] List of {name=string, title=string}
function M.get_all()
	local result = {}
	for _, name in ipairs(M.order) do
		local mod = M.get_lesson(name)
		if mod then
			result[#result + 1] = { name = name, title = mod.title }
		end
	end
	return result
end

--- Get all sections with loaded lessons for menu rendering.
--- @return table[] List of {title=string, lessons={{name, title}}}
function M.get_sections()
	local result = {}
	for _, section in ipairs(M.sections) do
		local sec = { title = section.title, lessons = {} }
		for _, name in ipairs(section.lessons) do
			local mod = M.get_lesson(name)
			if mod then
				sec.lessons[#sec.lessons + 1] = { name = name, title = mod.title }
			end
		end
		if #sec.lessons > 0 then
			result[#result + 1] = sec
		end
	end
	return result
end

--- Clear the loaded cache (for development reloading).
function M.clear_cache()
	loaded = {}
end

return M
