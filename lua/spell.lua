-- TODO: one command
vim.api.nvim_create_user_command("Mkspell", function()
   local spellfile = vim.bo.spellfile:gsub(" ", "\\ ")
   vim.cmd("mkspell! " .. spellfile)
end, {})

vim.api.nvim_create_user_command("Edspell", function()
   local spellfile = vim.bo.spellfile:gsub(" ", "\\ ")
   vim.cmd("edit " .. spellfile)
end, {})

local H = {}

function H.spell_all_good()
   local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
   for _, line in ipairs(lines) do
      while true do
         local word, type = unpack(vim.fn.spellbadword(line))
         if word == "" or type ~= "bad" then
            break
         end
         vim.cmd.spellgood(word)
      end
   end
   -- exit visual mode
   local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
   vim.api.nvim_feedkeys(esc, vim.fn.mode(), false)
end

function H.enhanced_spell_good()
   local cword = vim.fn.expand("<cword>")
   vim.ui.input({ default = cword:lower(), prompt = "spell good" }, function(input)
      if not input then
         return vim.notify("Aborted")
      end
      input = vim.trim(input)
      vim.cmd.spellgood(input)
   end)
end

return H
