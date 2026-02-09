-- vimteacher/lessons/init.lua
-- Lesson registry, loader, and interface validation

local M = {}

-- Ordered list of lesson module names (add new lessons here)
M.order = {
  "basic_movement",
  "word_movement",
  "insert_mode",
}

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

--- Clear the loaded cache (for development reloading).
function M.clear_cache()
  loaded = {}
end

return M
