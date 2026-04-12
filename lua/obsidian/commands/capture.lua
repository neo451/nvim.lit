local log = require("obsidian.log")
local Note = require("obsidian.note")
local api = require("obsidian.api")

local capture_opts = {
   pos = "bot",
}

-- TODO: command structure change, capture should be in both normal and visual

return function()
   local text

   local viz = api.get_visual_selection()

   if viz then
      text = viz.lines
   else
      text = api.input("capture content", {}) -- TODO: opts.editor = true
      if not text then
         log.info("Aborted")
         return
      end
   end

   require("obsidian.lsp.handlers._workspace_symbol")(
      nil,
      vim.schedule_wrap(function(symbols)
         vim.ui.select(symbols, {
            prompt = "capture to",
            format_item = function(symbol)
               return symbol.name
            end,
         }, function(symbol)
            if not symbol then
               log.info("Aborted")
               return
            end
            local file = vim.uri_to_fname(symbol.location.uri)
            local note = Note.from_file(file)
            local section -- TODO: same type
            if symbol.data and not vim.tbl_isempty(symbol.data) then
               section = {
                  header = symbol.data.header,
                  level = symbol.data.level,
               }
            end
            -- TODO: boolean or something to signal success | just log
            note:insert_text(text, {
               section = section,
               placement = capture_opts.pos,
            })
            if viz then
               vim.api.nvim_buf_set_lines(0, viz.csrow - 1, viz.cerow, false, {})
            end
         end)
      end)
   )
end
