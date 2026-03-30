return function()
   local calendar = require("calendar")

   local cal = calendar.new({
      callback = function(date)
         vim.cmd("Obsidian today " .. date:format("%Y-%m-%d"))
      end,
      lsp = {
         hover = function(self, param, ctx, callback)
            local date = self:get_selected_date():format("%Y-%m-%d")
            local daily_note = Obsidian.dir / Obsidian.daily_notes_dir / (date .. ".md")
            if daily_note:exists() then
               callback({ contents = vim.fn.readfile(tostring(daily_note)) })
            else
               callback({ contents = "No daily note for " .. date })
            end
         end,
      },
   })

   cal:open()
end
