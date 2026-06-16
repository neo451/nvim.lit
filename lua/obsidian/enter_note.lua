local obsidian = require("obsidian")
local _actions = require("obsidian._actions")
local actions = require("obsidian.actions")

---@param note obsidian.Note
return function(note)
   require("obsidian.winbar") -- TODO: make only attach per note
   vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
   vim.wo.foldtext = "v:lua.vim.lsp.foldtext()"
   vim.wo.foldmethod = "expr"
   vim.wo.foldlevel = 99
   vim.cmd("norm zx")

   local bufnr = note.bufnr

   vim.lsp.semantic_tokens.enable(true, { bufnr = bufnr })

   pcall(function()
      vim.keymap.set("v", "<leader>nd", function()
         require("nldates").replace_selection({ format = "[[][[]YYYY-MM-DD[]][]]" })
      end)
   end)

   if vim.b[bufnr].obsidian_help then
      vim.bo[bufnr].readonly = false
   end

   pcall(function()
      vim.keymap.set("n", "<C-a>", function()
         require("obsidian.api").image_bigger()
      end, { desc = "Obsidian image bigger", buffer = bufnr })

      vim.keymap.set("n", "<C-x>", function()
         require("obsidian.api").image_smaller()
      end, { desc = "Obsidian image smaller", buffer = bufnr })
   end)

   -- TODO: normal mode counterparts
   vim.keymap.set("x", "<leader>ol", actions.link_new, { desc = "Link new" })
   vim.keymap.set("x", "<leader>oL", actions.link, { desc = "Link" })

   vim.keymap.set("n", "<leader>xt", _actions.process_image, { buffer = bufnr })

   vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { buffer = bufnr })
   vim.keymap.set("n", "<leader>p", function()
      if pcall(require, "obsidian.paste") then
         return "<cmd>Obsidian paste<cr>"
      else
         return "<cmd>Obsidian paste_img<cr>"
      end
   end, { buffer = bufnr, expr = true })

   vim.keymap.set("n", "<leader>;", obsidian.api.add_property, { buffer = bufnr })

   pcall(function()
      vim.keymap.set("n", "<leader>il", actions.insert_link, { buffer = bufnr })
      vim.keymap.set("n", "<leader>it", actions.insert_tag, { buffer = bufnr })
      vim.keymap.set("n", "<leader>ta", actions.tag_note, { buffer = bufnr })
   end)

   vim.keymap.set("n", "<leader>cb", obsidian.api.set_checkbox, { buffer = bufnr, desc = "Obsidian set checkbox" })

   vim.keymap.set(
      { "n", "x" },
      "<leader>cc",
      obsidian.api.toggle_checkbox,
      { buffer = note.bufnr, desc = "Obsidian toggle checkbox" }
   )
end
