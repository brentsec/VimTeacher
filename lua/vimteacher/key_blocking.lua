-- vimteacher/key_blocking.lua
-- Buffer-local key blocking helpers for lessons.

local M = {}

M.MOUSE_KEYS = {
	"<LeftMouse>",
	"<2-LeftMouse>",
	"<3-LeftMouse>",
	"<4-LeftMouse>",
	"<RightMouse>",
	"<2-RightMouse>",
	"<MiddleMouse>",
	"<ScrollWheelUp>",
	"<ScrollWheelDown>",
	"<ScrollWheelLeft>",
	"<ScrollWheelRight>",
}

local INSERT_KEYS = { "i", "I", "a", "A", "o", "O", "s", "S", "c", "C" }
local MODIFY_KEYS = { "d", "dd", "D", "r", "x", "X", "p", "P", "u", "J", "<C-r>", "~" }
local VISUAL_KEYS = { "v", "V", "<C-v>" }

local function to_set(keys)
	local set = {}
	for _, key in ipairs(keys or {}) do
		if type(key) == "string" and key ~= "" then
			set[key] = true
		end
	end
	return set
end

local function clear_or_block_mouse(opts)
	for _, key in ipairs(M.MOUSE_KEYS) do
		vim.keymap.set("n", key, "<Nop>", opts)
	end
end

--- Resolve canonical keys through the current adaptive key display map.
--- @param key_display table|nil
--- @param canonical_keys string[]|nil
--- @return string[]
function M.resolve_keys(key_display, canonical_keys)
	local out = {}
	local seen = {}
	for _, canonical in ipairs(canonical_keys or {}) do
		local display = (key_display and key_display[canonical]) or canonical
		if type(display) == "string" and display ~= "" and not seen[display] then
			seen[display] = true
			out[#out + 1] = display
		end
	end
	return out
end

--- Resolve a lesson's adaptive keys through the current display map.
--- @param lesson table|nil
--- @param key_display table|nil
--- @return string[]
function M.resolve_keys_for_lesson(lesson, key_display)
	return M.resolve_keys(key_display, lesson and lesson.adaptive_keys or {})
end

--- Block insert-entry, modify, visual, and mouse keys for a non-insert lesson.
--- @param buf number
--- @param exempt_keys string[]|nil
function M.block_insert_keys(buf, exempt_keys)
	local opts = { buffer = buf, noremap = true, silent = true }
	local exempt = to_set(exempt_keys)

	for _, key in ipairs(INSERT_KEYS) do
		if exempt[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, function()
				vim.notify("VimTeacher: Insert mode disabled during tutorial", vim.log.levels.WARN)
			end, opts)
		end
	end

	for _, key in ipairs(MODIFY_KEYS) do
		if exempt[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	for _, key in ipairs(VISUAL_KEYS) do
		if exempt[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
		end

	clear_or_block_mouse(opts)
end

--- Block keys for insert-type lessons while allowing a lesson's expected commands.
--- @param buf number
--- @param allowed string[]
--- @param allowed_modify string[]|nil
--- @param allowed_visual string[]|nil
function M.block_keys_for_insert_lesson(buf, allowed, allowed_modify, allowed_visual)
	local opts = { buffer = buf, noremap = true, silent = true }
	local allowed_set = to_set(allowed)
	local modify_allowed_set = to_set(allowed_modify)
	local visual_allowed_set = to_set(allowed_visual)

	for _, key in ipairs(allowed or {}) do
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end
	for _, key in ipairs(allowed_modify or {}) do
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end
	for _, key in ipairs(allowed_visual or {}) do
		pcall(vim.keymap.del, "n", key, { buffer = buf })
	end

	local all_allowed = {}
	for _, key in ipairs(allowed or {}) do
		all_allowed[#all_allowed + 1] = key
	end
	for _, key in ipairs(allowed_modify or {}) do
		all_allowed[#all_allowed + 1] = key
	end
	local hint_msg = "VimTeacher: Use " .. table.concat(all_allowed, ", ") .. " for this lesson"

	for _, key in ipairs(INSERT_KEYS) do
		if allowed_set[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, function()
				vim.notify(hint_msg, vim.log.levels.WARN)
			end, opts)
		end
	end

	for _, key in ipairs(MODIFY_KEYS) do
		if modify_allowed_set[key] or allowed_set[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		elseif #key > 1 and (modify_allowed_set[key:sub(1, 1)] or allowed_set[key:sub(1, 1)]) then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	for _, key in ipairs(VISUAL_KEYS) do
		if visual_allowed_set[key] then
			pcall(vim.keymap.del, "n", key, { buffer = buf })
		else
			vim.keymap.set("n", key, "<Nop>", opts)
		end
	end

	clear_or_block_mouse(opts)
end

return M
