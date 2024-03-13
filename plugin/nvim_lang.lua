vim.print("Nvim Lang was loaded")

-- TODO: Remove. This is only here for testing.
vim.opt.runtimepath:append("~/Documents/projects/nvim-lang-core/target/release")

vim.cmd(
	':highlight default NvimLanguageTypo guisp=#EB5757 gui=undercurl ctermfg=198 cterm=undercurl')

vim.cmd(
	':highlight default NvimLanguageGrammar guisp=#F2B24C gui=undercurl ctermfg=198 cterm=undercurl')

vim.cmd(
	':highlight default NvimLanguageMisc guisp=#8F7FFF gui=undercurl ctermfg=198 cterm=undercurl')

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

local namespace_id = vim.api.nvim_create_namespace('NvimLanguageNamespace')

local function apply_underline(nvim_lang_file, current_buffer_id)
	-- pub struct NvimLanguageLine {
	--     pub line_number: usize,
	--     pub start_column: usize,
	--     pub end_column: usize,
	--     pub options: NvimOptions,
	--     pub data_type: NvimLangLineType,
	-- }

	-- Typos,
	-- Punctuation,
	-- ConfusedWords,
	-- Redundancy,
	-- Casing,
	-- Grammar,
	-- Misc,
	-- Semantics,
	-- Typograph,
	-- Other,


	for _, nll in pairs(nvim_lang_file.nvim_lang_lines) do
		vim.print(nll)
		local buffer_id = current_buffer_id
		local line_number = nll.line_number
		local end_col = nll.end_column
		local start_col = nll.start_column

		if nll.data_type == "Typos" then
			vim.api.nvim_buf_set_extmark(
				buffer_id, namespace_id, line_number - 1, start_col,
				{
					end_row = line_number - 1,
					end_col = end_col,
					hl_group = 'NvimLanguageTypo'
				})
		elseif nll.data_type == "Redundancy" then
			vim.api.nvim_buf_set_extmark(
				buffer_id, namespace_id, line_number - 1, start_col,
				{
					end_row = line_number - 1,
					end_col = end_col,
					hl_group = 'NvimLanguageMisc'
				})
		else
			vim.api.nvim_buf_set_extmark(
				buffer_id, namespace_id, line_number - 1, start_col,
				{
					end_row = line_number - 1,
					end_col = end_col,
					hl_group = 'NvimLanguageGrammar'
				})
		end
	end
end

local function process(arg)
	local file = arg.file
	local timeout = 30000;

	main.start_processing(file);

	local timer = vim.loop.new_timer();

	timer:start(100, 100, vim.schedule_wrap(function()
		local nvim_lang_file = main.check_process()

		if nvim_lang_file and next(nvim_lang_file.nvim_lang_lines) then
			apply_underline(nvim_lang_file, arg.buf)
			timer:stop();
			return
		end

		-- INFO: Stop after 30 sec
		if timeout <= 0 then
			vim.notify("Nvim Lang Timeout! On " .. file)
			timer:stop();
		end

		timeout = timeout - 100;

		vim.print(nvim_lang_file)
	end))
end

vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
	group = vim.api.nvim_create_augroup('nvim_lang_on_window_enter', { clear = true }),
	callback = function(arg)
		if isNotValidNvimLangFile(arg) then
			return
		end
		vim.print("On WIN enter")
		vim.print(arg)
		process(arg)
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
		process(arg)
	end
})
