-- pcall(function()
require("obsidian").register_command("unlinked_mentions", { nargs = 0 })
require("obsidian").register_command("calendar", { nargs = 0 })
require("obsidian").register_command("capture", { nargs = 0, range = true })
require("obsidian").register_command("panel", { nargs = 0 })
require("obsidian").register_command("attachments", { nargs = 0 })
require("obsidian").register_command("places", { nargs = "*" })
require("obsidian").register_command("ai_links", { nargs = "?", range = true })
require("obsidian").register_command("unique_note", {
   nargs = "*",
   func = require("obsidian._unique_note").command,
})
-- end)

require("ui.winbar")
