local log = require("obsidian.log")
local api = require("obsidian.api")
local actions = require("obsidian.actions")

local capture_opts = {
   pos = "bot",
}

-- TODO: command structure change, capture should be in both normal and visual
-- :Obsidian capture <text> works
-- revisit org refile manual again

return function(data)
   local viz = api.get_visual_selection()
   local arg_text = data.args:len() > 0 and data.args

   local text
   if arg_text then
      text = arg_text
   elseif viz then
      text = viz.lines
   else
      text = api.input("capture content", {}) -- TODO: opts.editor = true
      if not text then
         log.info("Aborted")
         return
      end
   end

   actions.workspace_symbol(nil, function(entry)
      local user_data = entry.user_data
      -- TODO: pass user_data.section to insert_text once formalized
      local section = user_data.section
         and {
            header = user_data.section.header,
            level = user_data.section.level,
         }
      local note = user_data.note
      -- TODO: boolean or something to signal success | just log
      note:insert_text(text, {
         section = section,
         placement = capture_opts.pos,
      })
      if viz then
         vim.api.nvim_buf_set_lines(0, viz.csrow - 1, viz.cerow, false, {})
      end
   end)
end
