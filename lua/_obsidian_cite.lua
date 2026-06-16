pcall(function()
   require("obsidian-cite").setup({
      source = {
         type = "better-bibtex-json",
         path = "~/My Library.json",
      },
   })
end)
