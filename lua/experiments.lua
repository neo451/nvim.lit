require("qol.search")
require("qol.easymotion")
require("qol.lsp_dial")
require("spell")
require("babel").enable(true)

-- require("quickfix")
-- require("diy.fuzzy").enable(false)

-- require("ob_git").setup({
--    pull_on_startup = false,
-- })

-- require("dict-lsp")
vim.api.nvim_create_user_command("MediaDbDebugSearch", function(opts)
   local manager = require("obsidian.media-db.manager")
   local MediaType = require("obsidian.media-db.types").MediaType

   local args = vim.split(opts.args, "%s+", { trimempty = true })
   local query = args[1]
   if not query or query == "" then
      vim.notify("usage: MediaDbDebugSearch <query> [type] [api]", vim.log.levels.ERROR)
      return
   end

   local search_opts = {}
   if args[2] and MediaType[args[2]] then
      search_opts.types = { MediaType[args[2]] }
   end
   if args[3] then
      search_opts.apis = { args[3] }
   end

   local results = manager.search(query, search_opts)
   vim.print(string.format("=== %d results for %q ===", #results, query))
   vim.print(results)
end, {
   nargs = "+",
   desc = "Dump media-db search results via vim.print",
})
