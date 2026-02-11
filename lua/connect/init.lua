local treesitter = vim.treesitter

local getFilePath = function()
	-- Get the full path of the current file
	local file_path = debug.getinfo(1).source:sub(2)

	-- Extract the directory containing the file
	return vim.fn.fnamemodify(file_path, ":h")
end

local readAll = function(filePath)
	local file = io.open(filePath, "rb")
	if not file then
		return nil, "Error: Cannot open file " .. filePath
	end

	local content = file:read("*all")

	file:close()

	return content
end

local clear_buffer = function(buffer)
	vim.api.nvim_buf_set_lines(buffer, 0, -1, false, {})
	return buffer
end

local createBlankSqlBuffer = function()
	local buffer = clear_buffer(vim.api.nvim_create_buf(false, true))
	vim.api.nvim_buf_set_name(buffer, "embedded-sql")
	vim.api.nvim_set_option_value("buftype", "", { buf = buffer })
	vim.api.nvim_set_option_value("filetype", "sql", { buf = buffer })
	vim.api.nvim_set_option_value("modifiable", true, { buf = buffer })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buffer })
	return buffer
end

local generate_spaces = function(amount)
	local spaces = ""
	for _ = 1, amount do
		spaces = " " .. spaces
	end
	return spaces
end

local createSqlBuffer = function(matches, buffer, scratch_buffer)
	local lines = {}
	local empty = ""
	local start = 0
	local count = 0

	for _, match in matches do
		for _, nodes in pairs(match) do
			for _, node in ipairs(nodes) do
				local text = treesitter.get_node_text(node, buffer)
				count = count + 1
				vim.notify("text: " .. text .. ", count: " .. count)
				local start_row, start_col = node:start()
				local end_row = node:end_()
				local leading_spaces = generate_spaces(start_col)

				for _ = start, start_row - 1 do
					table.insert(lines, empty)
				end

				for line in text:gmatch("[^\r\n]+") do
					table.insert(lines, line)
				end

				lines[start_row + 1] = leading_spaces .. lines[start_row + 1]

				start = end_row + 1
			end
		end
	end

	vim.notify("total: " .. count)

	vim.api.nvim_buf_set_lines(scratch_buffer, 0, 0, true, lines)

	vim.lsp.start({
		name = "postgres_ls",
		bufnr = scratch_buffer,
	})

	return scratch_buffer
end

local getCaptures = function(buf, query_string)
	local filetype = vim.bo.filetype
	local query = treesitter.query.parse(filetype, query_string)
	local root = treesitter.get_parser(buf, filetype):parse()[1]:root()
	local captures = query:iter_matches(root, buf, 0, -1)
	local captures_exist = false

	for _ in captures do
		captures_exist = true
		break
	end

	return captures_exist and captures or nil
end

local copyBuffer = function(buffer, scratch_buffer, captures, query_string)
	local filetype = vim.bo.filetype
	local copied_buffer = createSqlBuffer(captures, buffer, scratch_buffer)

	treesitter.query.set(filetype, "injections", query_string)

	return copied_buffer
end

return {
	setup = function()
		local sqlCheckFilePath = getFilePath() .. "/queries/sql-check.scm"
		local query_string, error = readAll(sqlCheckFilePath)
		local win_options = {
			relative = "editor", -- relative to the editor area
			width = 60,
			height = 20,
			col = math.floor((vim.o.columns - 60) / 2),
			row = math.floor((vim.o.lines - 20) / 2),
			anchor = "NW",
			style = "minimal",
			border = "single", -- or "none", "double", etc.
		}

		if error then
			vim.notify(error, vim.log.levels.ERROR)
		else
			local group = vim.api.nvim_create_augroup("embedded-sql", { clear = true })
			local namespace = vim.api.nvim_create_namespace("embedded-sql")
			local buffer = vim.api.nvim_get_current_buf()
			local captures = getCaptures(buffer, query_string)
			if captures then
				local scratch_buffer = createBlankSqlBuffer()

				vim.api.nvim_open_win(copyBuffer(buffer, scratch_buffer, captures, query_string), true, win_options)

				-- Not sure of a better way to fix this, without this it keeps attaching to non SQL buffers
				vim.api.nvim_create_autocmd("LspAttach", {
					pattern = "*",
					group = group,
					callback = function(args)
						local bufnr = args.buf
						if bufnr ~= scratch_buffer then
							local clients = vim.lsp.get_clients()
							local client = nil
							for _, c in pairs(clients) do
								if c.name == "postgres_ls" then
									client = c
									break
								end
							end
							if client then
								vim.lsp.buf_detach_client(bufnr, client.id)
							end
						end
					end,
				})

				vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
					pattern = { "*.rs", "*.js", "*.jsx", "*.ts", "*.tsx" },
					group = group,
					callback = function()
						local current_captures = getCaptures(buffer, query_string)
						if current_captures then
							local copied_buffer =
								copyBuffer(buffer, clear_buffer(scratch_buffer), current_captures, query_string)
							local diagnostics = vim.diagnostic.get(copied_buffer)
							vim.diagnostic.reset(namespace, 0)
							vim.diagnostic.set(namespace, 0, diagnostics, {})
						end
					end,
				})
			end
		end
	end,
}
