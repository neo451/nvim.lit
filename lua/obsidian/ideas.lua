local M = {}
local api = require("obsidian.api")

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

--- Calculate the byte position after a UTF-8 character at the given byte position.
--- This is needed because visual selection cecol points to the start byte of the last
--- selected character, but we need the position after the full character.
---
---@param line     string  The line content
---@param byte_pos integer The 1-indexed byte position of the character start
---@return integer The 1-indexed byte position after the character (exclusive end)
local function get_utf8_char_end(line, byte_pos)
   if not line or byte_pos > #line then
      return byte_pos
   end
   local byte = line:byte(byte_pos)
   if not byte then
      return byte_pos
   end
   -- Determine UTF-8 character byte length from lead byte
   local char_bytes = 1
   if byte >= 240 then -- 11110xxx: 4-byte char
      char_bytes = 4
   elseif byte >= 224 then -- 1110xxxx: 3-byte char
      char_bytes = 3
   elseif byte >= 192 then -- 110xxxxx: 2-byte char
      char_bytes = 2
   end
   return byte_pos + char_bytes
end

---Wrap the visual selection in a wiki link and ask native LSP completion for targets.
---This is intentionally private for now while the interaction is being iterated on.
M._link = function()
   local viz = api.get_visual_selection()
   if not viz then
      log.err("`Obsidian _link` must be called in visual mode")
      return
   elseif #viz.lines ~= 1 then
      log.err("Only in-line visual selections allowed")
      return
   end

   local bufnr = vim.api.nvim_get_current_buf()
   local line = vim.api.nvim_buf_get_lines(bufnr, viz.csrow - 1, viz.csrow, false)[1]
   local start_col = viz.cscol - 1
   local end_col = get_utf8_char_end(line, viz.cecol) - 1

   vim.api.nvim_buf_set_text(bufnr, viz.csrow - 1, start_col, viz.cerow - 1, end_col, {
      "[[" .. viz.selection .. "]]",
   })
   require("obsidian.ui").update(bufnr)

   -- nvim_win_set_cursor() takes the insertion point as a zero-based byte column.
   vim.api.nvim_win_set_cursor(0, { viz.csrow, start_col + 2 + #viz.selection })

   -- Completion only applies its response while in insert mode. Queue the mode
   -- change first, then let the native completion UI request the candidates.
   vim.api.nvim_feedkeys("i", "n", false)
   vim.schedule(function()
      vim.lsp.completion.get()
   end)
end

return M
