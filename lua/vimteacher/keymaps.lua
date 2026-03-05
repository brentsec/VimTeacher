-- vimteacher/keymaps.lua
-- Runtime keymap snapshot + canonical key display resolution

local M = {}

local DEFAULT_CONFIG = {
	mode = "adaptive_display", -- strict | adaptive_display | adaptive_runtime
	distro = "auto", -- auto | lazyvim | neovim | ...
	overrides = {}, -- canonical_key -> display_key
}

local state = {
	config = vim.deepcopy(DEFAULT_CONFIG),
	snapshot = nil,
	augroup = nil,
}

local function normalize_config(input)
	local cfg = vim.tbl_deep_extend("force", vim.deepcopy(DEFAULT_CONFIG), input or {})
	if cfg.mode ~= "strict" and cfg.mode ~= "adaptive_display" and cfg.mode ~= "adaptive_runtime" then
		cfg.mode = "adaptive_display"
	end
	if type(cfg.distro) ~= "string" or cfg.distro == "" then
		cfg.distro = "auto"
	end
	if type(cfg.overrides) ~= "table" then
		cfg.overrides = {}
	end
	return cfg
end

local function detect_distro()
	if state.config.distro ~= "auto" then
		return state.config.distro
	end
	if vim.g.lazyvim_config ~= nil or package.loaded["lazyvim"] or package.loaded["lazyvim.util"] then
		return "lazyvim"
	end
	return "neovim"
end

local function is_simple_rhs_match(rhs, canonical)
	if type(rhs) ~= "string" or rhs == "" then
		return false
	end
	local canonical_norm = canonical:gsub("%s+", ""):lower()
	local rhs_norm = rhs:gsub("%s+", ""):lower()
	if rhs_norm == canonical_norm then
		return true
	end
	if rhs_norm == ("<cmd>normal!" .. canonical_norm .. "<cr>") then
		return true
	end
	return false
end

local function is_filtered_candidate(lhs)
	if type(lhs) ~= "string" or lhs == "" then
		return true
	end
	local lower = lhs:lower()
	if lower:find("<plug>", 1, true) then
		return true
	end
	if lower:find("<leader>", 1, true) or lower:find("<localleader>", 1, true) then
		return true
	end
	return false
end

local function score_candidate(lhs, canonical, source, distro)
	local score = 0
	if source == "override" then
		score = score + 10000
	end
	if lhs == canonical then
		score = score + 700
	end
	if lhs:find("<", 1, true) then
		score = score + 10
	else
		score = score + 200
	end
	if distro == "lazyvim" and lhs:lower():find("<leader>", 1, true) then
		score = score - 1000
	end
	score = score - #lhs
	return score
end

local function get_normal_maps()
	if not state.snapshot then
		M.capture()
	end
	return (state.snapshot and state.snapshot.n) or {}
end

local function canonical_mapped_away(maps, canonical)
	for _, map in ipairs(maps) do
		if map.lhs == canonical then
			if map.expr == 1 or map.callback ~= nil then
				return true
			end
			if not is_simple_rhs_match(map.rhs, canonical) then
				return true
			end
		end
	end
	return false
end

local function dedupe_candidates(candidates)
	local seen = {}
	local result = {}
	for _, c in ipairs(candidates) do
		if not seen[c.lhs] then
			seen[c.lhs] = true
			result[#result + 1] = c
		end
	end
	return result
end

local function setup_lazyvim_hook()
	if state.config.mode == "strict" then
		if state.augroup then
			pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
			state.augroup = nil
		end
		return
	end

	if state.augroup then
		pcall(vim.api.nvim_del_augroup_by_id, state.augroup)
	end
	state.augroup = vim.api.nvim_create_augroup("VimTeacherKeymaps", { clear = true })

	-- LazyVim registers some mappings late; refresh snapshot when that event appears.
	vim.api.nvim_create_autocmd("User", {
		group = state.augroup,
		pattern = "LazyVimStarted",
		callback = function()
			M.capture()
		end,
	})
end

function M.configure(opts)
	state.config = normalize_config(opts)
	setup_lazyvim_hook()
end

function M.is_adaptive_mode()
	return state.config.mode ~= "strict"
end

function M.capture()
	local ok, maps = pcall(vim.api.nvim_get_keymap, "n")
	state.snapshot = {
		n = (ok and maps) or {},
		distro = detect_distro(),
		captured_at = vim.loop.hrtime(),
	}
	return state.snapshot
end

function M.capture_deferred()
	if not M.is_adaptive_mode() then
		return
	end
	vim.defer_fn(function()
		M.capture()
	end, 0)
end

function M.resolve_key(canonical)
	if type(canonical) ~= "string" or canonical == "" then
		return {
			canonical = canonical,
			display = canonical,
			source = "fallback",
			blocked = false,
		}
	end

	local override = state.config.overrides[canonical]
	if type(override) == "string" and override ~= "" then
		return {
			canonical = canonical,
			display = override,
			source = "override",
			blocked = false,
		}
	end

	local maps = get_normal_maps()
	local distro = state.snapshot and state.snapshot.distro or detect_distro()
	local blocked = canonical_mapped_away(maps, canonical)

	local candidates = {}
	if not blocked then
		candidates[#candidates + 1] = { lhs = canonical, source = "canonical" }
	end

	for _, map in ipairs(maps) do
		if map.expr ~= 1 and map.callback == nil and is_simple_rhs_match(map.rhs, canonical) then
			candidates[#candidates + 1] = { lhs = map.lhs, source = "reverse" }
		end
	end

	candidates = dedupe_candidates(candidates)
	local filtered = {}
	for _, candidate in ipairs(candidates) do
		if not is_filtered_candidate(candidate.lhs) then
			candidate.score = score_candidate(candidate.lhs, canonical, candidate.source, distro)
			filtered[#filtered + 1] = candidate
		end
	end

	table.sort(filtered, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if #a.lhs ~= #b.lhs then
			return #a.lhs < #b.lhs
		end
		return a.lhs < b.lhs
	end)

	if #filtered > 0 then
		local best = filtered[1]
		return {
			canonical = canonical,
			display = best.lhs,
			source = best.source,
			blocked = blocked,
		}
	end

	return {
		canonical = canonical,
		display = canonical,
		source = "fallback",
		blocked = blocked,
	}
end

function M.resolve_many(canonical_keys)
	local display_by_key = {}
	local diagnostics = {
		custom = {},
		unresolved = {},
	}

	for _, canonical in ipairs(canonical_keys or {}) do
		local result = M.resolve_key(canonical)
		display_by_key[canonical] = result.display
		if result.display ~= canonical then
			diagnostics.custom[#diagnostics.custom + 1] = canonical .. "->" .. result.display
		elseif result.blocked then
			diagnostics.unresolved[#diagnostics.unresolved + 1] = canonical
		end
	end

	return display_by_key, diagnostics
end

return M
