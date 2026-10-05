require("obsidian").register_command("calendar", { nargs = 0 })
require("obsidian").register_command("capture", { nargs = 0, range = true })
require("obsidian").register_command("entities", {
   nargs = "*",
   complete = require("obsidian.commands.entities").complete,
})

require("obsidian").register_command("base", {
   nargs = "*",
   complete = require("obsidian.commands.base").complete,
})
