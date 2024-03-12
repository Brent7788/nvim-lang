vim.print("Nvim Lang was loaded")

-- TODO: Remove. This is only here for testing.
vim.opt.runtimepath:append("~/Documents/projects/nvim-lang-core/target/release")

local main = require("main")
vim.print(main)

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

local function apply_underline(nvim_lang_file)
	-- pub struct NvimLanguageLine {
	--     pub line_number: usize,
	--     pub start_column: usize,
	--     pub end_column: usize,
	--     pub options: NvimOptions,
	--     pub data_type: NvimLangLineType,
	-- }

	vim.cmd(
		':highlight default MyUnderline guisp=#EB5757 gui=undercurl ctermfg=198 cterm=undercurl')

	for _, nll in pairs(nvim_lang_file.nvim_lang_lines) do
		vim.print(nll)
		local namespace_id = vim.api.nvim_create_namespace('MyNamespace')
		-- TODO: Need to get buffer id from nvim_lang_file path
		local buffer_id = vim.api.nvim_get_current_buf()
		local line_number = nll.line_number
		local end_col = nll.end_column
		local start_col = nll.start_column
		vim.api.nvim_buf_set_extmark(
			buffer_id, namespace_id, line_number - 1, start_col,
			{
				end_row = line_number - 1,
				end_col = end_col,
				hl_group = 'MyUnderline'
			})
	end
end

vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
	group = vim.api.nvim_create_augroup('nvim_lang_on_window_enter', { clear = true }),
	callback = function(arg)
		if isNotValidNvimLangFile(arg) then
			return
		end
		vim.print("On WIN enter")
		vim.print(arg)
		local file = arg.file
		local timeout = 6000;

		main.start_processing(file);

		local timer = vim.loop.new_timer();

		timer:start(100, 100, vim.schedule_wrap(function()
			local n = main.check_process()

			if n and next(n.nvim_lang_lines) then
				apply_underline(n)
				timer:stop();
				return
			end

			-- INFO: Stop after one minute
			if timeout <= 0 then
				vim.notify("Nvim Lang Timeout!")
				timer:stop();
			end

			timeout = timeout - 100;

			vim.print(n)
		end))

		vim.print("End of WIN Enter")
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
