require("obsidian").register_command("calendar", { nargs = 0 })
require("obsidian").register_command("capture", { nargs = 0, range = true })
require("obsidian").register_command("attachments", { nargs = 0 })
require("obsidian").register_command("places", { nargs = "*" })

require("obsidian").register_command("base", {
   nargs = "*",
   complete = require("obsidian.commands.base").complete,
})

require("obsidian").register_command("cover_art", { nargs = "*" })

require("obsidian").register_command("prompts", {
   nargs = "*",
   note_action = true,
   complete = require("obsidian.commands.prompts").complete,
})
