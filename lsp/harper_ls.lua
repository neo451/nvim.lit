---@type vim.lsp.Config
return {
   cmd = { "harper-ls", "--stdio" },
   filetypes = { "markdown" },
   root_markers = { ".git" },
   settings = {
      ["harper-ls"] = {
         linters = {
            SpellCheck = false,
            SentenceCapitalization = false,
         },
         markdown = { IgnoreLinkTitle = true },
         isolateEnglish = true,
      },
   },
}
