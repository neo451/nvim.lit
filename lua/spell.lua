-- TODO: one command
vim.api.nvim_create_user_command("Mkspell", function()
   local spellfile = vim.bo.spellfile:gsub(" ", "\\ ")
   vim.cmd("mkspell! " .. spellfile)
end, {})

vim.api.nvim_create_user_command("Edspell", function()
   local spellfile = vim.bo.spellfile:gsub(" ", "\\ ")
   vim.cmd("edit " .. spellfile)
end, {})
