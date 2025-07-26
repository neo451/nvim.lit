-- pcall(function()
--   require("otter").activate()
-- end)

vim.wo.conceallevel = 2

pcall(function()
	vim.keymap.del("i", "<leader>f", { buffer = true })
	vim.keymap.del("i", "<leader>r", { buffer = true })
end)

vim.keymap.set("i", "<localleader>f", "<Plug>AddVimFootnote", { buffer = true })
vim.keymap.set("i", "<localleader>r", "<Plug>ReturnFromFootnote", { buffer = true })

pcall(function()
	local opts = { silent = true, noremap = true, buffer = true }
	local toggle = require("markdown-toggle")

	opts.expr = true -- required for dot-repeat in Normal mode
	vim.keymap.set("n", "<C-q>", toggle.quote_dot, opts)
	vim.keymap.set("n", "<C-l>", toggle.list_dot, opts)
	vim.keymap.set("n", "<Leader><C-l>", toggle.list_cycle_dot, opts)
	vim.keymap.set("n", "<C-n>", toggle.olist_dot, opts)
	vim.keymap.set("n", "<M-x>", toggle.checkbox_dot, opts)
	vim.keymap.set("n", "<Leader><M-x>", toggle.checkbox_cycle_dot, opts)
	vim.keymap.set("n", "<C-h>", toggle.heading_dot, opts)

	opts.expr = false -- required for Visual mode
	vim.keymap.set("x", "<C-q>", toggle.quote, opts)
	vim.keymap.set("x", "<C-l>", toggle.list, opts)
	vim.keymap.set("x", "<Leader><C-l>", toggle.list_cycle, opts)
	vim.keymap.set("x", "<C-n>", toggle.olist, opts)
	vim.keymap.set("x", "<M-x>", toggle.checkbox, opts)
	vim.keymap.set("x", "<Leader><M-x>", toggle.checkbox_cycle, opts)
	vim.keymap.set("x", "<C-h>", toggle.heading, opts)
end)

vim.keymap.set("n", "<leader>p", "<cmd>Obsidian paste_img<cr>", { buffer = true })
