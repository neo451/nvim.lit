local obsidian = require("obsidian")
local _actions = require("obsidian._actions")
local actions = require("obsidian.actions")

local function list_item_indent(line)
   local indent = line:match("^([ \t]*)[-+*][ \t]+") or line:match("^([ \t]*)%d+[.)][ \t]+")
   return indent and #indent
end

local function item_range(lines, start)
   local indent = list_item_indent(lines[start])
   if not indent then
      return
   end

   local finish = start
   for line_number = start + 1, #lines do
      local line = lines[line_number]
      local nested_indent = list_item_indent(line)
      local line_indent = #(line:match("^[ \t]*") or "")

      if
         (nested_indent and nested_indent <= indent) or (not nested_indent and line ~= "" and line_indent <= indent)
      then
         break
      end

      if line ~= "" then
         finish = line_number
      end
   end

   return start, finish
end

local function archive_path(note, bufnr)
   local path = tostring(note.path or require("obsidian.path").buffer(bufnr))
   if path == "" then
      return
   end

   local filename = vim.fs.basename(path)
   local stem = filename:match("^(.*)%.md$") or filename
   return vim.fs.joinpath(vim.fs.dirname(path), stem .. "-archive.md")
end

local function append_to_archive(path, lines)
   local file, err = io.open(path, "a+")
   if not file then
      return false, err
   end

   local size = file:seek("end")
   if size and size > 0 then
      file:seek("end", -1)
      if file:read(1) ~= "\n" then
         file:write("\n")
      end
   end

   file:seek("end")
   file:write(table.concat(lines, "\n"), "\n")
   return file:close()
end

local function archive_current_item(note, bufnr)
   local row = vim.api.nvim_win_get_cursor(0)[1]
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local start, finish = item_range(lines, row)
   if not start then
      return
   end

   local item = {}
   for line_number = start, finish do
      item[#item + 1] = lines[line_number]
   end

   local now = os.date("*t")
   item[1] = item[1]:gsub("[ \t]+$", "")
      .. string.format(" @%d-%d-%d-%02d:%02d", now.year, now.month, now.day, now.hour, now.min)

   local path = archive_path(note, bufnr)
   local ok, err = append_to_archive(path, item)
   if not ok then
      vim.notify("Could not archive item: " .. tostring(err), vim.log.levels.ERROR)
      return
   end

   vim.api.nvim_buf_set_lines(bufnr, start - 1, finish, false, {})
   vim.api.nvim_buf_call(bufnr, function()
      vim.cmd("silent write")
   end)
end

---@param note obsidian.Note
return function(note)
   -- require("obsidian.winbar") -- TODO: make only attach per note
   vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
   vim.wo.foldtext = "v:lua.vim.lsp.foldtext()"
   vim.wo.foldmethod = "expr"
   vim.wo.foldlevel = 99

   local bufnr = note.bufnr

   vim.lsp.semantic_tokens.enable(true, { bufnr = bufnr })

   _G.obsidian_unlink = function()
      require("obsidian.actions").unlink()
   end
   vim.keymap.set("n", "dl", function()
      vim.go.operatorfunc = "v:lua.obsidian_unlink"
      return "g@l"
      -- return require("obsidian.textobj").dl_expr()
   end, { buffer = true, expr = true, desc = "Obsidian Delete Link" })

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

   vim.keymap.set({ "n", "x" }, "<leader>ol", actions.link_new, { desc = "Link new" })
   require("obsidian.actions.process_image")
   -- vim.keymap.set({ "n", "x" }, "<leader>oL", actions._link, { desc = "Link" })

   -- vim.keymap.set("n", "<leader>xt", _actions.process_image, { buffer = bufnr })

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
   vim.keymap.set("n", "<leader>ca", function()
      archive_current_item(note, bufnr)
   end, { buffer = bufnr, desc = "Archive current list item" })

   vim.keymap.set(
      { "n", "x" },
      "<leader>cc",
      obsidian.api.toggle_checkbox,
      { buffer = note.bufnr, desc = "Obsidian toggle checkbox" }
   )
end
