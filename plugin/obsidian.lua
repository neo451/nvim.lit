pcall(function()
   require("obsidian").register_command("sync", { nargs = 0 })
   require("obsidian").register_command("unlinked_mentions", { nargs = 0 })
end)
