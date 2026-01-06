require("obsidian").register_command("albums", {
   nargs = 0,
})

pcall(function()
   require("obsidian").register_command("git", {
      complete = nil,
      nargs = "?",
   })
end)

require("obsidian").register_command("unlinked_mentions", {
   nargs = 0,
})
