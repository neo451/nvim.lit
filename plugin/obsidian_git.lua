pcall(function()
   require("obsidian").register_command("git", {
      complete = nil,
      nargs = "?",
   })
end)
