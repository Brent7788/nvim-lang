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
local nvim_language_files = {}

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

local function apply_underline(nvim_lang_file, current_buffer_id, file)
	if nvim_lang_file.file_path ~= file then
		return
	end

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

	local index = nil
	-- INFO: Remove existing nvim language file and highlight
	for i, value in ipairs(nvim_language_files) do
		if value.file == nvim_lang_file.file_path then
			index = i
			break
		end
	end

	vim.print(index)
	if index ~= nil then
		for _, x in ipairs(nvim_language_files[index].lines) do
			for _, n in ipairs(nvim_lang_file.nvim_lang_lines) do
				if x.line_number == n.line_number and x.start_column == n.start_column and x.end_column == n.end_column then
					goto continue
				end
			end

			vim.api.nvim_buf_del_extmark(current_buffer_id, namespace_id, x.extmar_id)

			::continue::
		end
		table.remove(nvim_language_files, index)
	end
	-- INFO: End of remove

	table.insert(nvim_language_files, {
		file = nvim_lang_file.file_path,
		lines = nvim_lang_file.nvim_lang_lines,
		buffer_id = current_buffer_id
	})

	for _, nll in pairs(nvim_lang_file.nvim_lang_lines) do
		local buffer_id = current_buffer_id
		local line_number = nll.line_number
		local end_col = nll.end_column
		local start_col = nll.start_column

		if nll.data_type == "Typos" then
			nll.extmar_id = vim.api.nvim_buf_set_extmark(
				buffer_id, namespace_id, line_number - 1, start_col,
				{
					end_row = line_number - 1,
					end_col = end_col,
					hl_group = 'NvimLanguageTypo'
				})
		elseif nll.data_type == "Redundancy" then
			nll.extmar_id = vim.api.nvim_buf_set_extmark(
				buffer_id, namespace_id, line_number - 1, start_col,
				{
					end_row = line_number - 1,
					end_col = end_col,
					hl_group = 'NvimLanguageMisc'
				})
		else
			nll.extmar_id = vim.api.nvim_buf_set_extmark(
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
			apply_underline(nvim_lang_file, arg.buf, file)
			timer:stop();
			return
		end

		-- INFO: Stop after 30 sec
		if timeout <= 0 then
			vim.notify("Nvim Lang Timeout! On " .. file)
			timer:stop();
		end

		timeout = timeout - 100;
	end))
end

vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
	group = vim.api.nvim_create_augroup('nvim_lang_on_window_enter', { clear = true }),
	callback = function(arg)
		if isNotValidNvimLangFile(arg) then
			return
		end

		process(arg)
	end
})

vim.api.nvim_create_autocmd('BufWritePost', {
	group = vim.api.nvim_create_augroup('nvim_lang_on_save', { clear = true }),
	callback = function(arg)
		if isNotValidNvimLangFile(arg) then
			return
		end

		process(arg)
	end
})

-- TODO: Create popup for on current line and not only on cursor position
local function popup()
	local current_line = vim.api.nvim_get_current_line()
	vim.print(current_line)

	if current_line == nil or current_line == '' then
		return
	end

	local current_buf_id = vim.api.nvim_get_current_buf()
	vim.print("Current Buf " .. current_buf_id)

	local nvim_language_file = nil
	for _, v in pairs(nvim_language_files) do
		if v.buffer_id == current_buf_id then
			nvim_language_file = v
		end
	end

	if nvim_language_file == nil then
		vim.notify("Nvim Language File does not exit for buffer " .. current_buf_id)
		return
	end

	local win_cursor_postion = vim.api.nvim_win_get_cursor(0)
	vim.print(win_cursor_postion)
	local line_number = win_cursor_postion[1]
	local line_column_index = win_cursor_postion[2]

	for _, line in ipairs(nvim_language_file.lines) do
		if line.line_number ~= line_number or line_column_index < line.start_column or line_column_index > line.end_column then
			goto continue
		end

		local options = line.options
		local prompt = line.data_type .. " for |" .. options.original .. "|"

		vim.print(line)

		vim.ui.select(options.options, {
			prompt = prompt,
			telescope = require("telescope.themes").get_cursor(),
		}, function(selected)
			if selected == nil then
				return
			end

			local current_new_line = current_line:gsub(options.original, selected)
			vim.api.nvim_set_current_line(current_new_line)
			-- BUG: After replacing current line with new line, it will remove exit typos highlights
			-- Calling save command as workaround
			vim.api.nvim_command("w")
		end)

		::continue::
	end
end

-- TODO: Remove this map and create a command for this.
vim.keymap.set("n", "<leader>ll", popup,
	{ desc = "Show current word typos ", noremap = true, silent = true }
)
