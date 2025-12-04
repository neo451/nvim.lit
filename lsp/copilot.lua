--- @type vim.lsp.ClientConfig
return {
   name = "copilot-language-server",
   cmd = { "copilot-language-server" },
   filetypes = { "lua" },
   root_markers = {
      ".git",
   },
}
