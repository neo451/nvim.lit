vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = "~/Vaults/1 Notes/nvim.md",
}

_G.Config = {} -- Define config table to be able to pass data between scripts

_G.Config.new_autocmd = function(event, pattern, desc, callback)
   local opts = {
      group = vim.api.nvim_create_augroup("custom-config", {}),
      pattern = pattern,
      callback = callback,
      desc = desc,
   }
   vim.api.nvim_create_autocmd(event, opts)
end

require("options")
require("experiments")

require("lsp")
require("autocmds")
require("keymaps")

local ok, err = pcall(function()
   vim.cmd("packadd fzf-lua")
   vim.cmd("packadd plenary.nvim")
   vim.cmd("packadd snacks.nvim")
   vim.cmd("packadd telescope.nvim")
   vim.cmd("packadd blink.cmp")
   -- vim.cmd("packadd nvim-cmp")
   vim.cmd("packadd mini.icons")
   vim.cmd("packadd mini.pick")
   vim.cmd("packadd coop.nvim")
   vim.cmd("packadd nvim.undotree")
   vim.cmd("packadd nvim.difftool")

   vim.opt.rtp:append("~/Plugins/obsidian.nvim")
   require("_obsidian")

   vim.opt.rtp:append("~/Plugins/feed.nvim/")
   require("_feed")

   vim.opt.rtp:append("~/Plugins/kanban.nvim/")
   require("kanban").setup({})

   vim.opt.rtp:append("~/Plugins/diy.nvim/")
   vim.opt.rtp:append("~/Plugins/nldates.nvim/")
   vim.opt.rtp:append("~/Plugins/templater.nvim/")
end)

if not ok then
   print(err)
end
