vim.wo.conceallevel = 2
vim.bo.shiftwidth = 2
vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { buffer = true })

vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldmethod = "expr"
vim.wo.foldlevel = 99
vim.cmd("norm zx")

vim.keymap.set("n", "j", "gj", { buffer = true })
vim.keymap.set("n", "k", "gk", { buffer = true })

vim.keymap.set("v", "<leader>nd", function()
   require("nldates").parse({
      callback = function(datestring)
         return "[[" .. datestring .. "]]"
      end,
   })
end)

pcall(function()
   vim.keymap.set("v", "<leader>nd", function()
      require("nldates").parse({
         callback = function(datestring)
            return "[[" .. datestring .. "]]"
         end,
      })
   end)
end)

pcall(function()
   vim.keymap.del("i", "<leader>f", { buffer = true })
   vim.keymap.del("i", "<leader>r", { buffer = true })
end)

vim.keymap.set("i", "<localleader>f", "<Plug>AddVimFootnote", { buffer = true })
vim.keymap.set("i", "<localleader>r", "<Plug>ReturnFromFootnote", { buffer = true })

pcall(function()
   local opts = { silent = true, noremap = true, buffer = true }
   local toggle = require("markdown-toggle")

   opts.expr = true -- required for dot-repeat in Normal mode
   vim.keymap.set("n", "<C-q>", toggle.quote_dot, opts)
   vim.keymap.set("n", "<C-l>", toggle.list_dot, opts)
   vim.keymap.set("n", "<Leader><C-l>", toggle.list_cycle_dot, opts)
   vim.keymap.set("n", "<C-n>", toggle.olist_dot, opts)
   vim.keymap.set("n", "<M-x>", toggle.checkbox_dot, opts)
   vim.keymap.set("n", "<Leader><M-x>", toggle.checkbox_cycle_dot, opts)
   vim.keymap.set("n", "<C-h>", toggle.heading_dot, opts)

   opts.expr = false -- required for Visual mode
   vim.keymap.set("x", "<C-q>", toggle.quote, opts)
   vim.keymap.set("x", "<C-l>", toggle.list, opts)
   vim.keymap.set("x", "<Leader><C-l>", toggle.list_cycle, opts)
   vim.keymap.set("x", "<C-n>", toggle.olist, opts)
   vim.keymap.set("x", "<M-x>", toggle.checkbox, opts)
   vim.keymap.set("x", "<Leader><M-x>", toggle.checkbox_cycle, opts)
   vim.keymap.set("x", "<C-h>", toggle.heading, opts)
end)

local ts = vim.treesitter

---@param node_type string | string[]
---@return boolean
local in_node = function(node_type)
   local function in_node(t)
      local node = ts.get_node()
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

vim.keymap.set("n", "<leader>p", "<cmd>Obsidian paste_img<cr>", { buffer = true })

local function paste_url()
   local util = require("obsidian.util")
   local api = require("obsidian.api")

   local function paste_link(link)
      local selection = api.get_visual_selection()
      if not selection then
         return
      end
      if selection.csrow ~= selection.cerow then
         return error("no working for multi-line")
      end
      local name = selection.selection
      local st, ed = selection.cscol, selection.cecol
      local row = selection.csrow
      local md_link = string.format("[%s](%s)", name, link)
      vim.api.nvim_buf_set_text(0, row - 1, st - 1, row - 1, ed, { md_link })
   end

   local clipborad_context = vim.fn.getreg("+")

   clipborad_context = clipborad_context and vim.trim(clipborad_context)

   if clipborad_context and util.is_url(clipborad_context) then
      paste_link(clipborad_context)
   else
      vim.ui.input({ prompt = "link: " }, function(input)
         if not input then
            return
         end
         local link = vim.trim(input)
         if link and util.is_url(link) then
            paste_link(link)
         end
      end)
   end
end

-- https://neovim.io
-- [neovim](https://neovim.io)

vim.keymap.set("v", "<leader>p", paste_url)

local function spell_all_good()
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

vim.keymap.set("x", "zg", spell_all_good)
