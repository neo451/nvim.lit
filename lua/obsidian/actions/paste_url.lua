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

local has_nvim_0_12 = vim.fn.has("nvim-0.12.0") == 1

--- Create an LSP TextEdit from a visual selection.
--- The edit uses UTF-8 byte offsets (matching our LSP server's offset_encoding).
---
---@param viz      obsidian.selection The visual selection
---@param new_text string             The replacement text
---@param bufnr    integer?           Buffer number (defaults to current buffer)
---@return lsp.TextDocumentEdit?
local function make_text_edit(viz, new_text, bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local line = vim.api.nvim_buf_get_lines(bufnr, viz.cerow - 1, viz.cerow, false)[1]

   if not line then
      return
   end

   -- Calculate the exclusive end position (byte after the last selected character)
   local end_col = get_utf8_char_end(line, viz.cecol)

   ---@diagnostic disable-next-line: return-type-mismatch TODO: emmylua bug?
   return {
      textDocument = {
         uri = vim.uri_from_fname(vim.api.nvim_buf_get_name(bufnr)),
         version = has_nvim_0_12 and vim.NIL or nil,
      },
      edits = {
         {
            range = {
               -- LSP positions are 0-indexed
               start = { line = viz.csrow - 1, character = viz.cscol - 1 },
               ["end"] = { line = viz.cerow - 1, character = end_col - 1 },
            },
            newText = new_text,
         },
      },
   }
end
--- Replace the visual selection with new text.
--- Returns the text edit that was (or would be) applied.
---
---@param viz      obsidian.selection
---@param new_text string
---@param opts     { apply: boolean? }? Options. apply defaults to true.
---@return lsp.TextDocumentEdit |?
local function replace_selection(viz, new_text, opts)
   opts = opts or {}
   local apply = opts.apply ~= false -- default to true

   local text_edit = make_text_edit(viz, new_text)

   if apply and text_edit then
      vim.lsp.util.apply_workspace_edit({ documentChanges = { text_edit } }, "utf-8")
      require("obsidian.ui").update(0)
   end

   return text_edit
end

local function native_visual_paste()
   local count = vim.v.count
   local register = vim.v.register
   local keys = (count > 0 and tostring(count) or "") .. (register ~= '"' and ('"' .. register) or "") .. "p"
   vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), "n", false)
end

local uri = require("obsidian.uri")
local api = require("obsidian.api")

-- TODO: if set clipboard+=unnamedplus, use clipboard module

---Paste a URI as a Markdown link over a visual selection; otherwise perform native visual `p`.
local paste_url = function()
   local url = vim.trim(vim.fn.getreg(vim.v.register, 0, false))
   if not uri.is_uri(url) or url:find("[%s<>]") then
      return native_visual_paste()
   end

   local viz = api.get_visual_selection({ strict = true })
   if not viz then
      return native_visual_paste()
   end

   local label = viz.selection:gsub("\\", "\\\\"):gsub("%[", "\\["):gsub("%]", "\\]")
   replace_selection(viz, ("[%s](%s)"):format(label, url))
end

vim.keymap.set("x", "p", paste_url, { buffer = true, desc = "Obsidian Paste URL" })
