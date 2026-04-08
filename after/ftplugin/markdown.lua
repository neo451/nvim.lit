local my_popup_group = vim.api.nvim_create_augroup("my_popup_group", {})
local inline_refactor = require("inline_refactor")

vim.keymap.set("n", "<leader>ai", inline_refactor.refactor, { desc = "Refactor code with AI" })

local ts = vim.treesitter

---@param node_type string | string[]
---@return boolean
local in_node = function(node_type)
   local function in_node(t)
      local has_parser, node = pcall(ts.get_node)
      if not has_parser then
         return false -- silent fail for 1) a older neovim version 2) don't have markdown parser 3) ci tests
      end
      while node do
         if node:type() == t then
            return true
         end
         node = node:parent()
      end
      return false
   end
   if type(node_type) == "string" then
      return in_node(node_type)
   elseif type(node_type) == "table" then
      for _, t in ipairs(node_type) do
         local is_in_node = in_node(t)
         if is_in_node then
            return true
         end
      end
   end
   return false
end

pcall(function()
   vim.keymap.set("v", "<leader>nd", function()
      require("nldates").replace_selection({ format = "[[][[]YYYY-MM-DD[]][]]" })
   end)
end)

vim.api.nvim_create_autocmd("MenuPopup", {
   pattern = "*",
   group = my_popup_group,
   desc = "Mouse popup menu",
   -- nested = true,
   callback = function()
      vim.cmd([[
    amenu disable PopUp.How-to\ disable\ mouse
    amenu     PopUp.Correct\ word  1z=
    amenu     PopUp.Add\ word  1z=

    amenu disable PopUp.Correct\ word
    amenu disable PopUp.Add\ word

  ]])
      if vim.fn.spellbadword(vim.fn.expand("<cword>"))[1] ~= "" then
         vim.cmd([[ amenu enable PopUp.Correct\ word ]])
         vim.cmd([[ amenu enable PopUp.Add\ word ]])
      end
   end,
})

vim.wo.conceallevel = 1
vim.cmd("setlocal spell")

vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldmethod = "expr"
vim.wo.foldlevel = 99
vim.cmd("norm zx")

vim.bo.shiftwidth = 2

vim.b.pandoc_compiler_args = "--bibliography=$REF --citeproc"
vim.cmd("compiler pandoc")

vim.keymap.set({ "i", "n" }, "<Tab>", function()
   if in_node("list_item") then
      return "<C-t>"
   else
      return "<Tab>"
   end
end, { expr = true })

vim.keymap.set({ "i", "n" }, "<S-Tab>", function()
   if in_node("list_item") then
      return "<C-d>"
   else
      return "<S-Tab>"
   end
end, { expr = true })

local H = require("spell")

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
            local clipboard = vim.fn.getreg("+")
            local link
            if clipboard:find("^([%a][%w+%-%.]*):(.*)$") then
               link = clipboard
            else
               link = require("mini.surround").user_input("Link")
            end
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
