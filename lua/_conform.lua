local pangu = require("pangu")

require("conform").setup({
   format_on_save = function(bufnr)
      local bufname = vim.api.nvim_buf_get_name(bufnr)

      -- List of path patterns to exclude from formatting
      local exclude_patterns = {
         "/Templates/",
         "/docs/Note.md",
      }

      for _, pattern in ipairs(exclude_patterns) do
         if bufname:match(pattern) then
            return -- returning nil skips formatting
         end
      end

      return { timeout_ms = 500, lsp_format = "fallback" }
   end,
   formatters_by_ft = {
      nix = { "alejandra" },
      lua = { "stylua" },
      markdown = { "prettier", "injected", "pangu" },
      quarto = { "prettier" },
      qml = { "qmlformat" },
      json = { "jq" },
      python = { "black" },
   },
   formatters = {
      pangu = {
         format = function(_, _, lines, callback)
            callback(nil, pangu.format_lines(lines))
         end,
      },
   },
})
