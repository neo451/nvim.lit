vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = {
      "~/.config/nvim/init.md",
      "~/.config/nvim/lib.md",
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
