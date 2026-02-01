local M = {}

function M.count_checkbox(note, pat)
   local count = 0
   for _, line in ipairs(note.contents) do
      if line:match(pat) then
         count = count + 1
      end
   end
   return count
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
