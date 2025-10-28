Config.snippet_add("dt", function()
   ---@diagnostic disable-next-line: return-type-mismatch
   return os.date("%Y-%m-%d %H:%M:%S")
end, { buffer = 0 })

vim.treesitter.start()
