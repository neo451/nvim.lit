require("obsidian").register_command("calendar", { nargs = 0 })
require("obsidian").register_command("capture", { nargs = 0, range = true })
require("obsidian").register_command("attachments", { nargs = 0 })
require("obsidian").register_command("places", { nargs = "*" })
require("obsidian").register_command("base", {
   nargs = "*",
   complete = require("obsidian.commands.base").complete,
})
require("obsidian").register_command("base_create", {
   nargs = "*",
   complete = function(arg_lead)
      local ok, names = pcall(require("obsidian._base").view_names)
      if not ok then
         return {}
      end
      return vim.tbl_filter(function(name)
         return vim.startswith(name, arg_lead)
      end, names)
   end,
})
require("obsidian").register_command("cover_art", { nargs = "*" })
require("obsidian").register_command("prompts", {
   nargs = "*",
   note_action = true,
   complete = require("obsidian.commands.prompts").complete,
})

-- require("obsidian").register_command("ai_links", { nargs = "?", range = true })
-- require("obsidian").register_command("panel", { nargs = 0 })
-- require("obsidian").register_command("unlinked_mentions", { nargs = 0 })
