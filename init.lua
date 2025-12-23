vim.opt.rtp:append("~/Plugins/lit.nvim/")

vim.g.lit = {
   init = {
      "~/Documents/Notes/nvim/lib.md",
      "~/Documents/Notes/nvim.md",
      "~/Documents/Notes/nvim/try.md",
   },
}

_G.Config = {} -- Define config table to be able to pass data between scripts

local ts = vim.treesitter

---@param node_type string | string[]
---@return boolean
_G.Config.in_node = function(node_type)
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

vim.cmd("packadd nvim.undotree")
vim.cmd("packadd nvim.difftool")

require("options")
require("experiments")

require("lsp")
require("autocmds")
require("keymaps")
