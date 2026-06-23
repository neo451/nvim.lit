require("render-markdown").setup({
   html = {
      comment = { conceal = false },
   },
})

require("markdown-plus").setup({})

vim.wo.conceallevel = 3

vim.lsp.codelens.enable(true, { bufnr = 0 })

vim.keymap.set("n", "<leader>cl", function()
   vim.lsp.codelens.run({})
end, { buf = 0 })

local header_navigation = require("markdown-plus.headers.navigation")

vim.keymap.set("n", "]]", function()
   header_navigation.next_header()
   vim.cmd("normal! zz")
end, { buffer = true, desc = "Jump to next header" })

vim.keymap.set("n", "[[", function()
   header_navigation.prev_header()
   vim.cmd("normal! zz")
end, { buffer = true, desc = "Jump to previous header" })

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

vim.wo.conceallevel = 1
vim.wo.spell = true
vim.bo.shiftwidth = 2
-- vim.b.pandoc_compiler_args = "--bibliography=$REF --citeproc"
vim.b.pandoc_compiler_args = "--citeproc"
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
