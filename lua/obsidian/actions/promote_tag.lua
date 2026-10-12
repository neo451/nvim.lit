local document = require("obsidian.document")
local log = require("obsidian.log")
local tags = require("obsidian.tag")

local namespace = vim.api.nvim_create_namespace("obsidian-promote-inline-tag")

---@param note obsidian.Note
---@param tag string
---@return boolean
local function has_tag(note, tag)
   local normalized = tags.normalize(tag)
   for _, existing in ipairs(note.tags or {}) do
      if tags.normalize(existing) == normalized then
         return true
      end
   end
   return false
end

---@param note obsidian.Note
---@param row integer
---@param col integer
---@return obsidian.TagOccurrence?
local function inline_tag_at(note, row, col)
   local bufnr = note.bufnr
   if not bufnr or not vim.api.nvim_buf_is_loaded(bufnr) then
      return
   end

   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   for _, occurrence in
      ipairs(tags.extract(lines, {
         document = document.get(bufnr),
         frontmatter_end_line = note.frontmatter_end_line,
         frontmatter_elements = note.frontmatter_elements,
      }))
   do
      local range = occurrence.range
      if
         occurrence.source == "inline"
         and range.start_row == row
         and range.start_col <= col
         and col < range.end_col
      then
         return occurrence
      end
   end
end

---@param note obsidian.Note
---@param params lsp.CodeActionParams?
---@return obsidian.TagOccurrence?
local function requested_tag(note, params)
   local position = params and params.range and params.range.start
   if not position then
      return
   end
   return inline_tag_at(note, position.line, position.character)
end

---@param bufnr integer
---@param occurrence obsidian.TagOccurrence
local function remove_tag(bufnr, occurrence)
   local range = occurrence.range
   local line = vim.api.nvim_buf_get_lines(bufnr, range.start_row, range.start_row + 1, false)[1] or ""
   local start_col, end_col = range.start_col, range.end_col

   -- Consume one adjacent space so promoting a tag does not leave a double space.
   if line:sub(start_col, start_col):match("[ \t]") then
      start_col = start_col - 1
   elseif line:sub(end_col + 1, end_col + 1):match("[ \t]") then
      end_col = end_col + 1
   end

   vim.api.nvim_buf_set_text(bufnr, range.start_row, start_col, range.end_row, end_col, {})
end

---@param bufnr integer
---@param row integer
---@param col integer
local function promote_tag(bufnr, row, col)
   if not vim.api.nvim_buf_is_loaded(bufnr) then
      return
   end

   local Note = require("obsidian.note")
   local note = Note.from_buffer(bufnr)
   local occurrence = inline_tag_at(note, row, col)
   if not occurrence then
      return log.warn("The inline tag is no longer at the requested position")
   end

   local already_present = has_tag(note, occurrence.tag)
   local extmark
   if not already_present then
      if not note:should_save_frontmatter() then
         return log.warn("Frontmatter is not enabled for this note")
      end

      extmark = vim.api.nvim_buf_set_extmark(bufnr, namespace, occurrence.range.start_row, occurrence.range.start_col, {
         right_gravity = true,
      })
      note:add_tag(occurrence.tag)
      if not note:update_frontmatter(bufnr) then
         vim.api.nvim_buf_del_extmark(bufnr, namespace, extmark)
         return log.warn("Could not add #%s to frontmatter", occurrence.tag)
      end

      local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, extmark, {})
      vim.api.nvim_buf_del_extmark(bufnr, namespace, extmark)
      occurrence = position[1] and inline_tag_at(Note.from_buffer(bufnr), position[1], position[2]) or nil
      if not occurrence then
         return log.warn("Added the tag to frontmatter, but could not remove its inline occurrence")
      end

      -- Keep the promotion as a single undo step when frontmatter was changed.
      pcall(vim.cmd.undojoin)
   end

   remove_tag(bufnr, occurrence)
end

require("obsidian").code_action.add({
   name = "promote_inline_tag",
   title = "Promote inline tag to frontmatter",
   cond = function(note, params)
      local occurrence = requested_tag(note, params)
      return occurrence ~= nil and (has_tag(note, occurrence.tag) or note:should_save_frontmatter())
   end,
   arguments = function(note, params)
      local occurrence = requested_tag(note, params)
      if not occurrence then
         return {}
      end
      return { note.bufnr, occurrence.range.start_row, occurrence.range.start_col }
   end,
   fn = promote_tag,
})
