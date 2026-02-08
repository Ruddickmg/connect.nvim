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
	return buffer
end

local generate_spaces = function(amount)
	local spaces = ""
	for _ = 1, amount do
		spaces = " " .. spaces
	end
	return spaces
end

local createSqlBuffer = function(captures, buffer, scratch_buffer)
	local lines = {}
	local empty = ""
	local start = 0

	vim.api.nvim_buf_set_option(scratch_buffer, "modifiable", true)

	for _, node in captures do
		local text = treesitter.get_node_text(node, buffer)
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

	vim.api.nvim_buf_set_lines(scratch_buffer, 0, 0, true, lines)

	vim.notify("scratch buffer: " .. scratch_buffer .. ", main buffer:" .. buffer)

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
	local captures = query:iter_captures(root, buf)
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
			vim.notify(error, "error")
		else
			local group = vim.api.nvim_create_augroup("embedded-sql", { clear = true })
			local buffer = vim.api.nvim_get_current_buf()
			local captures = getCaptures(buffer, query_string)
			if captures then
				local scratch_buffer = createBlankSqlBuffer()

				vim.api.nvim_open_win(copyBuffer(buffer, scratch_buffer, captures, query_string), true, win_options)
				vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
					pattern = { "*.rs", "*.js", "*.jsx", "*.ts", "*.tsx" },
					group = group,
					callback = function()
						local current_captures = getCaptures(buffer, query_string)
						if current_captures then
							vim.notify("doing stuff")
							copyBuffer(buffer, clear_buffer(scratch_buffer), current_captures, query_string)
						end
					end,
				})
			end
		end
	end,
}
