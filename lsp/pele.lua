---@type vim.lsp.Config
return {
   cmd = { "node", vim.fn.expand("~/Projects/pele-lsp/server.js"), "--stdio" },
   filetypes = { "mermaid", "markdown", "quarto" },
   root_markers = { ".git", ".obsidian", "package.json" },
}
