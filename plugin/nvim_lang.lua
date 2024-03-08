vim.notify("Hello From Nvim Lang")


local _ = vim.fn.getcwd()

local buf_info = vim.fn.getbufinfo()

-- vim.print(buf_info)

vim.api.nvim_create_autocmd({ 'BufWinEnter' }, {
	group = vim.api.nvim_create_augroup('nvim_lang_on_window_enter', { clear = true }),
	callback = function(arg)
		if arg == nil or arg.file == nil or arg.file == "" then
			return
		end
		vim.print("On WIN enter")
		vim.print(arg)
	end
})

vim.api.nvim_create_autocmd('BufWritePost', {
	group = vim.api.nvim_create_augroup('nvim_lang_on_save', { clear = true }),
	callback = function(arg)
		if arg == nil or arg.file == nil or arg.file == "" then
			return
		end

		vim.print("On save")
		vim.print(arg)
	end
})
