vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = "~/Vaults/Notes/nvim.md",
}

require("options")
require("lsp")
require("autocmds")
require("keymaps")
require("experiments")

pcall(function()
   vim.cmd("packadd fzf-lua")
   vim.cmd("packadd plenary.nvim")
   vim.cmd("packadd snacks.nvim")
   vim.cmd("packadd telescope.nvim")
   vim.cmd("packadd blink.cmp")
   vim.cmd("packadd nvim-cmp")
   vim.cmd("packadd mini.icons")
   vim.cmd("packadd mini.pick")
   vim.cmd("packadd coop.nvim")
end)

vim.opt.rtp:append("~/Plugins/obsidian.nvim")
vim.opt.rtp:append("~/Plugins/diy.nvim/")
vim.opt.rtp:append("~/Plugins/nldates.nvim/")
vim.opt.rtp:append("~/Plugins/templater.nvim/")
vim.opt.rtp:append("~/Plugins/kanban.nvim/")
vim.opt.rtp:append("~/Plugins/feed.nvim/")

require("_feed")

require("kanban").setup({})

require("diy.fuzzy").enable(false)

require("_obsidian")

-- require("ob_git").setup({
--    pull_on_startup = false,
-- })
--
require("babel").enable(true)

vim.g.node_host_prog = vim.fn.exepath("neovim-node-host")
