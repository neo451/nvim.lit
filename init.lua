vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = {
      "~/Documents/Notes/Projects/nvim/lib.md",
      "~/Documents/Notes/Projects/nvim/nvim.md",
   },
}

vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")

require("helpers")
require("options")
require("experiments")

require("lsp")
require("autocmds")
require("keymaps")
