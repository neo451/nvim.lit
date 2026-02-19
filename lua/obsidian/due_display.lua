local obsidian = require("obsidian")
local api = vim.api

local ns_id = api.nvim_create_namespace("obsidian.due_display")

---@param bnr integer
---@param line_num integer
---@param text string
---@param id integer
---@return integer|?
local function display_result(bnr, line_num, text, id)
   local current_line_marks = api.nvim_buf_get_extmarks(
      bnr,
      ns_id,
      { line_num, 0 },
      { line_num, -1 },
      { details = true }
   )

   if not vim.tbl_isempty(current_line_marks) then
      local mark = current_line_marks[1]
      local mark_text = mark[4] and mark[4].virt_text and mark[4].virt_text[1] and mark[4].virt_text[1][1]

      if mark_text == text then
         return -- already has the same mark, skip
      else
         vim.api.nvim_buf_del_extmark(bnr, ns_id, mark[1])
      end
      return
   end

   local opts = {
      id = id,
      virt_text = { { text, "DiagnosticVirtualTextHint" } },
      virt_text_pos = "eol",
   }
   local mark_id = api.nvim_buf_set_extmark(bnr, ns_id, line_num, 0, opts)
   return mark_id
end

local id_c = 1

local function update_dues(buf)
   local path = vim.api.nvim_buf_get_name(buf)
   if not vim.endswith(path, "todo.md") then
      return
   end
   local ok, note = pcall(obsidian.Note.from_buffer, buf)
   if not ok then
      return
   end
   for _, link_match in ipairs(note:links()) do
      local line = link_match.line - 1
      local loc = obsidian.util.parse_link(link_match.link)
      if loc then
         local notes = obsidian.search.resolve_note(loc)
         if #notes == 1 then
            local ref = notes[1]
            local due = ref.metadata.due
            if due then
               local id = display_result(buf, line, due, id_c)
               if id then
                  id_c = id_c + 1
               end
            end
         else
            -- obsidian.log.info("failed to resolve note link")
         end
      end
   end
end

-- TODO: through diagnostic
-- TODO: multiple link, note resolve ...
vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function(ev)
      update_dues(ev.buf)
   end,
})

vim.api.nvim_create_autocmd("BufWritePost", {
   pattern = "todo.md",
   callback = function(ev)
      update_dues(ev.buf)
   end,
})
