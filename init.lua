vim.opt.rtp:append("~/Plugins/lit.nvim/")

require("options")
require("lsp")
require("autocmds")
require("keymaps")

vim.keymap.set("n", "<leader>E", "<cmd>e ~/.config/litvim/init.md<cr>")

-- pcall(function()
-- 	require("vim._extui").enable({})
-- end)

vim.cmd("packadd plenary.nvim")
vim.cmd("packadd snacks.nvim")

vim.opt.rtp:append("~/Plugins/obsidian.nvim")

require("_obsidian")
