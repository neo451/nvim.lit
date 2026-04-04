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
   "copilot",
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

_G.obsidian_statusline = function()
   local s = vim.g.obsidian_sync_status or ""
   return s == "" and "" or (s .. " ")
end

_G.rime_statusline = function()
   local s = vim.g.rime_enabled and "ㄓ" or ""
   return s == "" and "" or (s .. " ")
end

vim.o.statusline = "%<%f %h%m%r%=%{%v:lua.obsidian_statusline()%}%{%v:lua.rime_statusline()%}%-14.(%l,%c%V%) %P"
