local obsidian = require("obsidian")

vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function()
      local note = obsidian.api.current_note()
      if not note then
         return
      end
      if vim.tbl_isempty(note.metadata) then
         return
      end
      local options = note.metadata.nvim
      if not options or vim.tbl_isempty(options) then
         return
      end
      for k, v in pairs(note.metadata.nvim) do
         vim.o[k] = v
      end
   end,
})
