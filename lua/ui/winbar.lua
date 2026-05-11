local M = {}

local function daily_folder()
   if not _G.Obsidian or not Obsidian.opts or not Obsidian.opts.daily_notes then
      return nil
   end
   local folder = Obsidian.opts.daily_notes.folder
   if not folder then
      return nil
   end
   return tostring(Obsidian.dir / folder)
end

local function buf_in_daily(buf)
   local folder = daily_folder()
   if not folder then
      return false
   end
   local name = vim.api.nvim_buf_get_name(buf)
   if name == "" then
      return false
   end
   return name:sub(1, #folder) == folder
end

function M.daily_progress()
   local buf = vim.api.nvim_get_current_buf()
   local ok, note = pcall(require("obsidian").Note.from_buffer, buf)
   if not ok or not note then
      return ""
   end
   local res = require("obsidian._utils").count_checkbox(note)
   if res.total == 0 then
      return ""
   end
   return string.format("Daily: %d/%d", res.done, res.total)
end

local group = vim.api.nvim_create_augroup("ui_winbar_daily", { clear = true })

vim.api.nvim_create_autocmd("User", {
   group = group,
   pattern = "ObsidianNoteEnter",
   callback = function(ev)
      if buf_in_daily(ev.buf) then
         vim.wo.winbar = "%{%v:lua.require'ui.winbar'.daily_progress()%}"
      end
   end,
})

return M
