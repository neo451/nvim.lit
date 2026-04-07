local M = {}

local util = require("obsidian.util")

function M.count_checkbox(note)
   local done = 0
   local total = 0
   for _, line in ipairs(note.contents) do
      if util.is_checkbox(line) then
         total = total + 1
         if line:match("%[x%]") then
            done = done + 1
         end
      end
   end
   return { total = total, done = done }
end

local filetypes = {
   "snacks_picker_input",
   "TelescopePrompt",
   "minipick",
   "fzf",
}

function M.create_new_from_picker_prompt()
   if vim.list_contains(filetypes, vim.bo.filetype) then
      local id
      if vim.bo.filetype == "fzf" then
         id = Obsidian.picker.state.class._last_query
         local buf = vim.api.nvim_get_current_buf()
         require("fzf-lua").hide()
         vim.api.nvim_chan_send(vim.bo[buf].channel, "\x1b")
      else
         id = vim.trim(vim.api.nvim_get_current_line())
         vim.cmd("startinsert")
         vim.cmd("norm q")
      end

      vim.cmd("Obsidian new " .. id)
   end
end

return M
