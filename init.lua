vim.loader.enable()
vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = {
      "~/.config/nvim/init.md",
      "~/.config/nvim/lib.md",
   },
}

vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")
vim.cmd("packadd nvim.tohtml")
vim.cmd("packadd nohlsearch")
vim.cmd("packadd cfilter")

require("options")
require("experiments")

local servers = {
   -- "lua_ls",
   "rime_ls",
   "emmylua_ls",
   "gopls",
   "nixd",
   "zls",
   "ts_ls",
   "qmlls",
   "pyright",
   "ts_ls",
   -- "copilot",
   -- "markdown_oxide"
   -- "marksman",
   -- "mpls",
   -- "dummy_ls",
   -- "harper_ls",
}

for _, name in ipairs(servers) do
   pcall(vim.lsp.enable, name)
end

vim.lsp.inline_completion.enable()

require("autocmds")
require("keymaps")

vim.opt.statusline = "%!v:lua.require'ui.statusline'.render()"
