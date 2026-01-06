local log = require("obsidian.log")

return function()
   local note = require("obsidian").api.current_note()
   if not note then
      return
   end

   -- TODO: include aliases
   local query = note:display_name()

   -- TODO: buf workspace dir

   ---@type vim.quickfix.entry[]
   local entries = {}
   require("obsidian.search").search_async(
      Obsidian.dir,
      query,
      {},
      function(match)
         -- TODO: generalized matchdata to quickfix entry
         entries[#entries + 1] = {
            filename = match.path.text,
            lnum = match.line_number,
            end_lnum = match.line_number,
            col = match.submatches[1].start + 1,
            end_col = match.submatches[1]["end"] + 1,
            text = vim.trim(match.lines.text),
         }
      end,
      vim.schedule_wrap(function(code)
         if code ~= 0 then
            log.error("failed to serach unlinked mentions")
         end
         Obsidian.picker.pick(entries)
      end)
   )
end
