local M = {}

function M.new_counter()
	local state = {
		pass_count = 0,
		fail_count = 0,
	}

	local function assert_test(condition, msg)
		if condition then
			state.pass_count = state.pass_count + 1
		else
			state.fail_count = state.fail_count + 1
			print("  FAIL: " .. msg)
		end
	end

	local function finish(label, opts)
		local suffix = opts and opts.suffix or ""
		if suffix ~= "" then
			suffix = " " .. suffix
		end
		print(string.format("%s: %d passed, %d failed%s", label, state.pass_count, state.fail_count, suffix))
		if state.fail_count > 0 then
			vim.cmd("cquit! 1")
		end
	end

	return {
		assert_test = assert_test,
		finish = finish,
		state = state,
	}
end

return M
