pcall(function()
   local indent = require("blink.indent")
   indent.enable(false)
end)

vim.wo.conceallevel = 1
vim.bo.shiftwidth = 2
vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { buffer = true })

vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.wo.foldmethod = "expr"
vim.wo.foldlevel = 99
vim.cmd("norm zx")

vim.b.pandoc_compiler_args = "--bibliography=/mnt/c/Users/lenovo/Documents/bib.bib --citeproc"
vim.cmd("compiler pandoc")

-- vim.bo.makeprg =
--    "pandoc % -f markdown -t docx -o %.docx --bibliography=/mnt/c/Users/lenovo/Documents/bib.bib --citeproc"

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

-- pcall(function()
--    vim.keymap.del("i", "<leader>f", { buffer = true })
--    vim.keymap.del("i", "<leader>r", { buffer = true })
-- end)

vim.keymap.set("i", "<localleader>f", "<Plug>AddVimFootnote", { buffer = true })
vim.keymap.set("i", "<localleader>r", "<Plug>ReturnFromFootnote", { buffer = true })

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

vim.keymap.set("n", "zg", enhanced_spell_good)

-- Set markdown-specific surrounding in 'mini.surround'
vim.b.minisurround_config = {
   custom_surroundings = {
      -- Markdown link. Common usage:
      -- `saiwL` + [type/paste link] + <CR> - add link
      -- `sdL` - delete link
      -- `srLL` + [type/paste link] + <CR> - replace link
      L = {
         input = { "%[().-()%]%(.-%)" },
         output = function()
            local link = require("mini.surround").user_input("Link: ")
            return { left = "[", right = "](" .. link .. ")" }
         end,
      },
      l = {
         input = { "%[().-()%]%(.-%)" },
         output = function()
            local name = require("mini.surround").user_input("name: ")
            return { left = "[" .. name .. "](", right = ")" }
         end,
      },
   },
}

local function is_dot(path)
   return vim.startswith(path, "...")
end

local function absolute(path)
   -- local base = vim.fs.basename(path):sub(1, -5)
   path = path:gsub("%.%.%./", "")
   local mods = vim.loader.find(path, { all = true })
   if #mods ~= 0 then
      return mods[1].modpath
   else
      return path
   end
end

local function rtp(path)
   local paths = vim.split(vim.o.rtp, ",")
   -- path = path:gsub("%.%.%./", "")
   path = vim.fs.basename(path)

   -- print(path)

   for _, dir in ipairs(paths) do
      local res = vim.fs.find({ path }, { path = dir })
      if not vim.tbl_isempty(res) then
         vim.print(res)
      end
   end
end

-- rtp(".../obsidian/version.lua")

-- _G.pager_includeexpr = function()
--    local word = vim.api.nvim_get_current_line() -- TODO:
--    local resolved_path = absolute(word)
--    return absolute(word)
-- end
--
-- vim.bo.includeexpr = "v:lua.pager_includeexpr()"
