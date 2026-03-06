-- vimteacher/recent.lua
-- Shared helpers for avoiding immediate repetition when picking random items.

local M = {}

--- Clear a recent-picks FIFO in place.
--- @param recent_state number[]
function M.clear(recent_state)
	for i = #recent_state, 1, -1 do
		recent_state[i] = nil
	end
end

--- Pick an index while avoiding recently used entries when possible.
--- Mutates `recent_state` in place as a FIFO queue.
--- @param pool_size number
--- @param recent_state number[]
--- @param max_recent number|nil
--- @return number
function M.pick_avoiding_recent(pool_size, recent_state, max_recent)
	if type(pool_size) ~= "number" or pool_size < 1 then
		error("pick_avoiding_recent requires a positive pool size")
	end

	local recent_set = {}
	for _, idx in ipairs(recent_state) do
		recent_set[idx] = true
	end

	local eligible = {}
	for i = 1, pool_size do
		if not recent_set[i] then
			eligible[#eligible + 1] = i
		end
	end

	if #eligible == 0 then
		M.clear(recent_state)
		for i = 1, pool_size do
			eligible[i] = i
		end
	end

	local idx = eligible[math.random(1, #eligible)]
	recent_state[#recent_state + 1] = idx

	local limit = max_recent or 5
	while #recent_state > limit do
		table.remove(recent_state, 1)
	end

	return idx
end

return M
