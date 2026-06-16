-- TODO: one command
vim.api.nvim_create_user_command("Mkspell", function()
   local spellfiles = vim.bo.spellfile:gsub(" ", "\\ ")
   -- local afffile = vim.g.spell_aff:gsub(" ", "\\ ")
   -- local cmd = ("mkspell! " .. spellfile .. " " .. afffile)
   for spellfile in vim.gsplit(spellfiles, ",") do
      local cmd = ("mkspell! " .. spellfile)
      vim.cmd(cmd)
   end
end, {})

vim.api.nvim_create_user_command("Edspell", function()
   local spellfile = vim.bo.spellfile:gsub(" ", "\\ ")
   vim.cmd("edit " .. spellfile)
end, {})

local my_popup_group = vim.api.nvim_create_augroup("my_popup_group", {})

vim.api.nvim_create_autocmd("MenuPopup", {
   pattern = "*",
   group = my_popup_group,
   desc = "Mouse popup menu",
   callback = function()
      vim.cmd([[
    amenu disable PopUp.How-to\ disable\ mouse
    amenu     PopUp.Correct\ word  1z=
    amenu     PopUp.Add\ word  zg

    amenu disable PopUp.Correct\ word
    amenu disable PopUp.Add\ word

  ]])
      if vim.fn.spellbadword(vim.fn.expand("<cword>"))[1] ~= "" then
         vim.cmd([[ amenu enable PopUp.Correct\ word ]])
         vim.cmd([[ amenu enable PopUp.Add\ word ]])
      end
   end,
})

local function get_spell_in_visual_region()
   local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
   local results = {}
   for _, line in ipairs(lines) do
      while true do
         local word, type = unpack(vim.fn.spellbadword(line))
         if word == "" or type ~= "bad" then
            break
         end
         results[#results + 1] = word
      end
   end
   return results
end

local function spell_all_good()
   local badwords = get_spell_in_visual_region()
   for _, word in ipairs(badwords) do
      vim.cmd.spellgood(word)
   end
   -- exit visual mode
   local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
   vim.api.nvim_feedkeys(esc, vim.fn.mode(), false)
end

local function enhanced_spell_good()
   local cword = vim.fn.expand("<cword>")
   vim.ui.input({ default = cword:lower(), prompt = "spell good" }, function(input)
      if not input then
         return vim.notify("Aborted")
      end
      input = vim.trim(input)
      vim.cmd.spellgood(input)
   end)
end

vim.keymap.set("x", "zg", spell_all_good)
vim.keymap.set("n", "zg", enhanced_spell_good)
