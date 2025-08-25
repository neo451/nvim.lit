vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = "/home/n451/Vaults/Notes/nvim.md",   
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
   vim.cmd("packadd mini.icons")
   vim.cmd("packadd mini.pick")
end)

vim.opt.rtp:append("~/Plugins/obsidian.nvim")
vim.opt.rtp:append("~/Plugins/nvim-anki/")

require("_obsidian")
