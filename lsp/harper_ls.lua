---@type vim.lsp.Config
return {
   cmd = { "harper-ls", "--stdio" },
   filetypes = { "markdown" },
   root_markers = { ".git" },
   settings = {},
}
