require("qol.search")
require("qol.easymotion")
require("spell")

require("experiments.md_live_ls")

-- require("quickfix")
-- require("diy.fuzzy").enable(false)

-- require("ob_git").setup({
--    pull_on_startup = false,
-- })

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

vim.api.nvim_create_user_command("Lsp", "checkhealth vim.lsp", {})

require("vim._extui").enable({})

-- require("ui.statusline")
require("ui.tabline")
require("ui.argpoon").setup({})

require("babel").enable(true)

local ok, err = pcall(function()
   vim.cmd("packadd fzf-lua")
   vim.cmd("packadd plenary.nvim")
   vim.cmd("packadd snacks.nvim")
   vim.cmd("packadd telescope.nvim")
   vim.cmd("packadd blink.cmp")
   vim.cmd("packadd mini.nvim")
   vim.cmd("packadd coop.nvim")

   vim.opt.rtp:append("~/Plugins/obsidian.nvim")
   require("_obsidian")

   vim.opt.rtp:append("~/Plugins/feed.nvim/")
   require("_feed")

   vim.opt.rtp:append("~/Plugins/diy.nvim/")
   vim.opt.rtp:append("~/Plugins/nldates.nvim/")
   vim.opt.rtp:append("~/Plugins/templater.nvim/")
   vim.opt.rtp:append("~/Plugins/dict-lsp.nvim/")
   require("dict-lsp")
   vim.opt.rtp:append("~/Plugins/obpilot/")
   require("obpilot")
   vim.opt.rtp:append("~/Plugins/calendar.nvim/")
end)

if not ok then
   print(err)
end

-- require("dict-lsp")
