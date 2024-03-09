vim.print("Nvim Lang was loaded")

local _ = vim.fn.getcwd()

local buf_info = vim.fn.getbufinfo()

local function end_of_path(path)
	local path_split = vim.split(path, '/', { trimempty = true })
	local last_index_path = #path_split
	return path_split[last_index_path]
end

local function isNotValidNvimLangFile(arg)
	if arg == nil or arg.file == nil or arg.file == "" then
		return true
	end

	local file_end = end_of_path(arg.file);

	-- TODO: Need to support more file type, not just only Rust.
	--	 Need to make this more dynamic.
	if file_end == nil or file_end == "" or file_end:find(".rs", 1, true) == nil then
		return true
	end

	return false
end

vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
	group = vim.api.nvim_create_augroup('nvim_lang_on_window_enter', { clear = true }),
	callback = function(arg)
		if isNotValidNvimLangFile(arg) then
			return
		end
		vim.print("On WIN enter")
		vim.print(arg)
	end
})

vim.api.nvim_create_autocmd('BufWritePost', {
	group = vim.api.nvim_create_augroup('nvim_lang_on_save', { clear = true }),
	callback = function(arg)
		if isNotValidNvimLangFile(arg) then
			return
		end

		vim.print("On save")
		vim.print(arg)
	end
})
