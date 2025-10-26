require("qol.search")

vim.filetype.add({
   extension = {
      base = "yaml",
   },
})

vim.api.nvim_create_user_command("Sort", function(opts)
   if not tonumber(opts.args) then
      print("Error: Argument must be a number")
      return
   end
   local bang = opts.bang and "!" or ""
   local range = opts.range == 0 and "" or ("%d,%d"):format(opts.line1, opts.line2)
   local pattern = string.format("%ssort%s /^\\([^|]*|\\)\\{%s\\}/", range, bang, opts.args)
   vim.cmd(pattern)
end, { nargs = 1, bang = true, range = true })

vim.api.nvim_create_user_command("Mkspell", function(opts)
   vim.cmd("mkspell! " .. vim.o.spellfile)
end, {})

vim.api.nvim_create_user_command("Lsp", "checkhealth vim.lsp", {})

require("vim._extui").enable({})

require("ui.statusline")
require("ui.tabline")
-- require("diy.fuzzy").enable(false)

-- require("ob_git").setup({
--    pull_on_startup = false,
-- })
require("babel").enable(true)

-- require("quickfix")
