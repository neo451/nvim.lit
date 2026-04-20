require("qol.search")
require("qol.easymotion")
require("spell")

-- require("quickfix")
-- require("diy.fuzzy").enable(false)

-- require("ob_git").setup({
--    pull_on_startup = false,
-- })

require("babel").enable(true)

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

-- require("dict-lsp")
