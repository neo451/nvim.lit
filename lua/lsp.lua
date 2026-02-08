local servers = {
   -- "lua_ls",
   "emmylua_ls",
   "gopls",
   "nixd",
   "zls",
   "ts_ls",
   "dummy_ls",
   "qmlls",
   "pyright",
   "ts_ls",
   "copilot",
   -- "marksman",
   -- "mpls",
   -- "rime_ls",
   -- "harper_ls",
}

for name in vim.iter(servers) do
   pcall(vim.lsp.enable, name)
end

vim.lsp.inline_completion.enable()
