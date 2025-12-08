vim.wo.conceallevel = 1
vim.bo.shiftwidth = 2

vim.treesitter.start()

vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldmethod = "expr"
vim.wo.foldlevel = 99
vim.cmd("norm zx")

vim.keymap.set("n", "<leader>pp", function()
   vim.fn.jobstart({ "tatum", "serve", "--open", vim.fn.expand("%") })
end, { buffer = true, silent = true })

vim.b.pandoc_compiler_args = "--bibliography=$REF --citeproc"
vim.cmd("compiler pandoc")

vim.keymap.set({ "i", "n" }, "<Tab>", function()
   if _G.Config.in_node("list_item") then
      return "<C-t>"
   else
      return "<Tab>"
   end
end, { expr = true })

vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
   if _G.Config.in_node("list_item") then
      return "<C-d>"
   else
      return "<S-Tab>"
   end
end, { expr = true })

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

-- vim.keymap.set("v", "<leader>p", H.paste_url)
vim.keymap.set("x", "zg", H.spell_all_good, { buffer = true })
vim.keymap.set("n", "zg", H.enhanced_spell_good, { buffer = true })

-- Markdown link. Common usage:
-- `saiwL` + [type/paste link] + <CR> - add link
-- `sdL` - delete link
-- `srLL` + [type/paste link] + <CR> - replace link
vim.b.minisurround_config = {
   custom_surroundings = {
      L = {
         input = { "%[().-()%]%(.-%)" },
         output = function()
            local link = require("mini.surround").user_input("Link")
            if not link then
               return
            end
            return { left = "[", right = "](" .. link .. ")" }
         end,
      },
      l = {
         input = { "%[().-()%]%(.-%)" },
         output = function()
            local name = require("mini.surround").user_input("Name")
            if not name then
               return
            end
            return { left = "[" .. name .. "](", right = ")" }
         end,
      },
   },
}
