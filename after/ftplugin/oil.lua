vim.keymap.set("n", "<leader>gg", function()
   local dir = require("oil").get_current_dir()
   require("neogit").open({
      cwd = dir,
   })
end, { buffer = true })

-- TODO: some obsidian.nvim operations here: bookmark file, bookmark folder
