vim.opt.rtp:append("~/Plugins/lit.nvim/")

require("options")
require("lsp")
require("autocmds")
require("keymaps")

vim.keymap.set("n", "<leader>E", "<cmd>e ~/.config/litvim/init.md<cr>")

-- pcall(function()
-- 	require("vim._extui").enable({})
-- end)

pcall(function()
   vim.cmd("packadd fzf-lua")
   vim.cmd("packadd plenary.nvim")
   vim.cmd("packadd snacks.nvim")
   vim.cmd("packadd telescope.nvim")
   vim.cmd("packadd blink.cmp")
   vim.cmd("packadd mini.icons")
end)

vim.opt.rtp:append("~/Plugins/obsidian.nvim")
vim.opt.rtp:append("~/Plugins/nvim-anki/")

vim.api.nvim_create_user_command("WeeklyRecap", function()
   local Note = require("obsidian.note")

   Note.create({
      title = string.format("Week %d, %d", os.date("%V"), os.date("%Y")),
      id = string.format("%d-W%02d", os.date("%Y"), os.date("%V")),
      dir = Obsidian.dir / "journal/weekly-review",
      tags = { "journal", "weekly-recap" },
   }):open()
end, { desc = "Create weekly recap note" })

require("_obsidian")

require("ui.statusline")
