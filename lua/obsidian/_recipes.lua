local paste_from_path = function()
   local path = vim.fn.getreg("+")
   path = vim.trim(path)
   -- TODO: check looks like a path
   vim.schedule(function()
      require("obsidian.attachment").add(path, { insert = true })
   end)
end

vim.keymap.set("n", "<leader><leader>p", paste_from_path, { buffer = true, expr = true })
