return function()
   local calendar = require("calendar")

   local cal = calendar.new({
      callback = function(date)
         vim.cmd("Obsidian today " .. date:format("%Y-%m-%d"))
      end,
   })

   cal:open()
end
