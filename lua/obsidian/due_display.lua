local obsidian = require("obsidian")
local api = vim.api

local ns_id = api.nvim_create_namespace("due display")

---@param bnr integer
---@param line_num integer
---@param text string
---@param id integer
---@return integer
local function display_result(bnr, line_num, text, id)
   local opts = {
      id = id,
      virt_text = { { text, "DiagnosticVirtualTextHint" } },
      virt_text_pos = "eol",
   }
   local mark_id = api.nvim_buf_set_extmark(bnr, ns_id, line_num, 0, opts)
   return mark_id
end

local id_c = 1

-- TODO: through diagnostic
-- TODO: multiple link, note resolve ...
vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function(ev)
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if not vim.endswith(path, "todo.md") then
         return
      end
      local ok, note = pcall(obsidian.Note.from_buffer, ev.buf)
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
                  display_result(ev.buf, line, "<- " .. due, id_c)
                  id_c = id_c + 1
               end
            else
               -- obsidian.log.info("failed to resolve note link")
            end
         end
      end
   end,
})
