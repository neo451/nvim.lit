vim.opt.rtp:append("~/Plugins/lit.nvim/")

require("options")
require("lsp")
require("autocmds")
require("keymaps")

vim.keymap.set("n", "<leader>E", "<cmd>e ~/.config/litvim/init.md<cr>")

-- pcall(function()
-- 	require("vim._extui").enable({})
-- end)

vim.cmd("packadd fzf-lua")
vim.cmd("packadd plenary.nvim")
vim.cmd("packadd snacks.nvim")
vim.cmd("packadd telescope.nvim")
vim.cmd("packadd blink.cmp")

-- vim.opt.rtp:append("~/Plugins/obsidian.nvim")
vim.opt.rtp:append("~/Plugins/3_13/")

require("_obsidian")
