return {
   "pandoc (from markdown)",
   builder = function()
      local file = vim.fn.expand("%:p")
      local output_file = file:gsub("%.md", ".docx")
      return {
         cmd = {
            "pandoc",
            "--from",
            "markdown",
            "--to",
            "docx", -- TODO: input
            "--citeproc",
            "--output",
            output_file,
            file,
            -- "--bibliography=$REF",
         },
      }
   end,
   condition = {
      filetype = { "markdown" },
   },
}
