vim.print("Nvim Lang was loaded")
local M = {}

-- TODO: Remove. This is only here for testing.
--
-- vim.opt.runtimepath:append("~/Documents/projects/nvim-lang-core/target/release")

-- local path = vim.fn.getcwd()
-- vim.opt.runtimepath:append("lua/")

-- local n = vim.api.nvim_get_runtime_file
-- vim.cmd(
-- 	':highlight default NvimLanguageTypo guisp=#EB5757 gui=undercurl ctermfg=198 cterm=undercurl')
--
vim.cmd(
	':highlight default NvimLanguageTypo guisp=#1bfa32 gui=undercurl ctermfg=198 cterm=undercurl')

vim.cmd(
	':highlight default NvimLanguageGrammar guisp=#F2B24C gui=undercurl ctermfg=198 cterm=undercurl')

vim.cmd(
	':highlight default NvimLanguageMisc guisp=#8F7FFF gui=undercurl ctermfg=198 cterm=undercurl')

-- vim.loop.new_timer():start(3000, 0, vim.schedule_wrap(function()
-- 	local main = require("main")
-- 	vim.print(main)
-- end))

local main = nil
-- vim.print(main)
-- main.languagetool_docker_setup()

-- local j = vim.fn.getcwd()
-- vim.print(j)

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

	return main.does_support_language(arg.file) ~= true
end

local function get_buffer_id_by_file_name(file_path)
	local buf_info = vim.fn.getbufinfo()
	for _, buffer in ipairs(buf_info) do
		if file_path == buffer.name then
			return buffer.bufnr
		end
	end
	return -1
end

local namespace_id = vim.api.nvim_create_namespace('NvimLanguageNamespace')

local function apply_underline(nvim_lang_file, current_buffer_id, file)
	if nvim_lang_file.file_path ~= file then
		current_buffer_id = get_buffer_id_by_file_name(nvim_lang_file.file_path)

		if current_buffer_id == -1 then
			vim.notify("Unable to apply underline highlight because the files does not match!")
			vim.print('Nvim Language File ->' .. nvim_lang_file.file_path .. '<-')
			vim.print('From your project ->' .. file .. '<-')
			return
		end
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

	if index ~= nil then
		local nvim_language_extmarks = vim.api.nvim_buf_get_extmarks(current_buffer_id, namespace_id, 0, -1, {});

		for _, value in ipairs(nvim_language_extmarks) do
			vim.api.nvim_buf_del_extmark(current_buffer_id, namespace_id, value[1])
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

		-- INFO: Stop after 30 sec
		if timeout <= 0 then
			vim.notify("Nvim Lang Timeout! On " .. file)
			timer:stop();
		end

		timeout = timeout - 100;

		if nvim_lang_file and next(nvim_lang_file.nvim_lang_lines) then
			apply_underline(nvim_lang_file, arg.buf, file)
			timer:stop();
			return
		end
	end))
end

-- BUG: This does not work with git sign and fugitive
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

local function on_win_cursor_nvim_lang_line(line_fn)
	local current_line = vim.api.nvim_get_current_line()

	if current_line == nil or current_line == '' then
		return
	end

	local current_buf_id = vim.api.nvim_get_current_buf()

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
	local line_number = win_cursor_postion[1]
	local line_column_index = win_cursor_postion[2]

	for _, line in ipairs(nvim_language_file.lines) do
		if line.line_number ~= line_number or line_column_index < line.start_column or line_column_index > line.end_column then
			goto continue
		end

		line_fn(line, current_line)

		if line then
			break
		end

		::continue::
	end
end

-- TODO: Create popup for on current line and not only on cursor position
local function spelling_suggestions_popup()
	on_win_cursor_nvim_lang_line(function(line, current_line)
		local options = line.options
		local prompt = line.data_type .. " on |" .. options.original .. "|"

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
	end)
end

local function add_current_word_position_to_dictionary()
	on_win_cursor_nvim_lang_line(function(line, _)
		local options = line.options
		local original = options.original

		if original == nil or original == "" then
			-- TODO: Find better message
			vim.print("Cannot add empty word")
		end

		main.add_word(original)
		vim.api.nvim_command("w")
	end)
end

local function select_word_to_remove()
	local words = main.get_words()
	vim.print("Remove word start")
	vim.print(words)

	vim.ui.select(words, {
		prompt = "Select word to remove:",
		telescope = require("telescope.themes").get_cursor(),
	}, function(selected)
		if selected == nil then
			return
		end

		main.remove_word(selected)
		vim.api.nvim_command("w")
	end)
end

-- TODO: Remove this map and create a command for this.
vim.keymap.set("n", "<leader>ll", spelling_suggestions_popup,
	{ desc = "Show current word typos ", noremap = true, silent = true }
)

-- TODO: Remove this map and create a command for this.
vim.keymap.set("n", "<leader>la", add_current_word_position_to_dictionary,
	{ desc = "Add current word to dictionary ", noremap = true, silent = true }
)

-- TODO: Remove this map and create a command for this.
vim.keymap.set("n", "<leader>lr", select_word_to_remove,
	{ desc = "Remove word from dictionary ", noremap = true, silent = true }
)

M.setup = function()
	vim.notify("Call test is working")
end

vim.api.nvim_create_user_command('NvimLanguageTestCmd', function()
	vim.notify('Hello from nvim lang command')
	main = require("main")
	vim.print(main)
	main.languagetool_docker_setup()
end, {})

return M
