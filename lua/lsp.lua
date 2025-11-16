local servers = {
   "lua_ls",
   "gopls",
   "nixd",
   "zls",
   "ts_ls",
   "dummy_ls",
   -- "rime_ls",
   -- "harper_ls",
   -- "emmylua_ls",
}

for name in vim.iter(servers) do
   pcall(vim.lsp.enable, name)
end
