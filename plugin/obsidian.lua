pcall(function()
   require("obsidian").register_command("git", {
      complete = nil,
      nargs = "?",
   })

   require("obsidian").register_command("unlinked_mentions", {
      nargs = 0,
   })
end)
