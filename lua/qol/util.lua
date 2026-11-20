local M = {}

---@class qol.Selection
---@field lines string[]
---@field selection string
---@field csrow integer
---@field cscol integer
---@field cerow integer
---@field cecol integer

--- Get the current visual selection of text and exit visual mode.
---
---@param opts { strict: boolean|? }|?
---
---@return qol.Selection|?
M.get_visual_selection = function(opts)
   opts = opts or {}
   -- Adapted from fzf-lua:
   -- https://github.com/ibhagwan/fzf-lua/blob/6ee73fdf2a79bbd74ec56d980262e29993b46f2b/lua/fzf-lua/utils.lua#L434-L466
   -- this will exit visual mode
   -- use 'gv' to reselect the text
   local _, csrow, cscol, cerow, cecol
   local mode = vim.fn.mode()
   if opts.strict and not vim.endswith(string.lower(mode), "v") then
      return
   end

   if mode == "v" or mode == "V" or mode == "" then
      -- if we are in visual mode use the live position
      _, csrow, cscol, _ = unpack(vim.fn.getpos("."))
      _, cerow, cecol, _ = unpack(vim.fn.getpos("v"))
      if mode == "V" then
         -- visual line doesn't provide columns
         cscol, cecol = 0, 999
      end
      -- exit visual mode
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<Esc>", true, false, true), "n", true)
   else
      -- otherwise, use the last known visual position
      _, csrow, cscol, _ = unpack(vim.fn.getpos("'<"))
      _, cerow, cecol, _ = unpack(vim.fn.getpos("'>"))
   end

   -- Swap vars if needed
   if cerow < csrow then
      csrow, cerow = cerow, csrow
      cscol, cecol = cecol, cscol
   elseif cerow == csrow and cecol < cscol then
      cscol, cecol = cecol, cscol
   end

   local lines = vim.fn.getline(csrow, cerow)
   assert(type(lines) == "table", "lines is not a table")
   if vim.tbl_isempty(lines) then
      return
   end

   -- When the whole line is selected via visual line mode ("V"), cscol / cecol will be equal to "v:maxcol"
   -- for some odd reason. So change that to what they should be here. See ':h getpos' for more info.
   local maxcol = vim.api.nvim_get_vvar("maxcol")
   if cscol == maxcol then
      cscol = vim.fn.strlen(lines[1] or "")
   end
   if cecol == maxcol then
      cecol = vim.fn.strlen(lines[#lines] or "")
   end

   -- Use nvim_buf_get_text which properly handles UTF-8 byte positions.
   -- getpos() returns byte-indexed positions (1-indexed). Visual selection is
   -- inclusive, so cecol points to the first byte of the last selected
   -- character; advance past the full character for the exclusive end.
   local bufnr = vim.api.nvim_get_current_buf()

   local line = vim.api.nvim_buf_get_lines(bufnr, cerow - 1, cerow, false)[1]

   local end_col_for_extraction = cecol
   if line and cecol <= #line then
      end_col_for_extraction = cecol + vim.str_utf_end(line, cecol) + 1
   end

   local selection_lines = vim.api.nvim_buf_get_text(
      bufnr,
      csrow - 1, -- start row (convert to 0-indexed)
      cscol - 1, -- start col in bytes (convert to 0-indexed)
      cerow - 1, -- end row (convert to 0-indexed)
      end_col_for_extraction - 1, -- end col: exclusive, convert to 0-indexed
      {}
   )

   local selection = table.concat(selection_lines, "\n")

   return {
      lines = lines,
      selection = selection,
      csrow = csrow,
      cscol = cscol,
      cerow = cerow,
      cecol = cecol,
   }
end

return M
