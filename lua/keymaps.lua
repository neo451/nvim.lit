local set = vim.keymap.set

vim.keymap.set("i", "jk", "<esc>l")

vim.keymap.set("n", "<leader>H", function()
   vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
   vim.notify(vim.lsp.inlay_hint.is_enabled() and "Inlay Hint Enabled" or "Inlay Hint Disabled")
end)

vim.keymap.set("n", "gra", function()
   local ok, tiny = pcall(require, "tiny-code-action")
   if ok then
      tiny.code_action({})
   else
      vim.lsp.buf.code_action()
   end
end)

set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
set({ "n", "x" }, "<Down>", "v:count == 0 ? 'gj' : 'j'", { desc = "Down", expr = true, silent = true })
set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })
set({ "n", "x" }, "<Up>", "v:count == 0 ? 'gk' : 'k'", { desc = "Up", expr = true, silent = true })

set("n", "<C-S-;>", require("qol.search").query_browser, { remap = true })

-- mini version control!
set("n", "ycc", function()
   return "yy" .. vim.v.count1 .. "gcc']p"
end, { remap = true, expr = true })

-- fix previous spell error
set("i", "<C-l>", "<Esc>[s1z=`]a")

-- Copy/paste with system clipboard
set({ "n", "x" }, "gY", '"+Y', { desc = "Copy to system clipboard" })
set({ "n", "x" }, "gy", '"+y', { desc = "Copy to system clipboard" })
set("n", "gp", '"+p', { desc = "Paste from system clipboard" })
-- - Paste in Visual with `P` to not copy selected text (`:h v_P`)
set("x", "gp", '"+P', { desc = "Paste from system clipboard" })

set("n", "<leader>U", "<cmd>Undotree<cr>", { desc = "Toggle UndoTree" })

set("n", "<End>", "<cmd>restart<cr>")

set("n", "grl", function()
   vim.lsp.buf.document_link({ loclist = false })
end)

set("n", "<C-S-C>", function()
   local buf = vim.api.nvim_get_current_buf()
   local file = vim.api.nvim_buf_get_name(buf)

   vim.ui.input({ prompt = "To copy: ", default = file }, function(input)
      if input then
         vim.fn.setreg("+", input)
         vim.notify("Copied filename to clipboard", 2)
      end
   end)
end)

--search within visual selection - this is magic
set("x", "/", "<Esc>/\\%V")

-- better J: keep cursor in place
set("n", "J", "mzJ`z:delmarks z<cr>")

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
set("n", "n", "'Nn'[v:searchforward].'zv'", { expr = true, desc = "Next Search Result" })
set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
set("n", "N", "'nN'[v:searchforward].'zv'", { expr = true, desc = "Prev Search Result" })
set("x", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })
set("o", "N", "'nN'[v:searchforward]", { expr = true, desc = "Prev Search Result" })

-- Add undo break-points
set("i", ",", ",<c-g>u")
set("i", ".", ".<c-g>u")
set("i", ";", ";<c-g>u")

-- better indenting
set("v", "<", "<gv")
set("v", ">", ">gv")

local nmap_leader = function(suffix, rhs, desc, opts)
   opts = opts or {}
   vim.keymap.set("n", "<Leader>" .. suffix, rhs, vim.tbl_extend("keep", { desc = desc }, opts))
end

nmap_leader("<leader>x", function()
   local file = vim.fn.expand("%")
   local base = vim.fs.basename(file)
   if vim.endswith(base, ".qml") then
      vim.system({ "qs" })
   elseif vim.startswith(base, "test_") then
      return "<cmd>lua MiniTest.run_file()<cr>"
   elseif vim.endswith(base, "_spec.lua") then
      local has_neotest, neotest = pcall(require, "neotest")
      if has_neotest then
         neotest.run.run(file)
         return "<cmd>Neotest output-panel<cr>"
      else
         return "<cmd>!busted %<cr>"
      end
   else
      return "<cmd>w<cr><cmd>so %<cr>"
   end
end, "", { expr = true })

nmap_leader("<leader>X", function()
   return "<cmd>lua MiniTest.run_at_location()<cr>"
end, "", { expr = true })

--- zen mode (no neck pain)
nmap_leader("<leader>z", "<cmd>NoNeckPain<cr>")

-- For 'mini.clue'
-- _G.Config.leader_group_clues = {
--    { mode = "n", keys = "<Leader>b", desc = "+Buffer" },
--    { mode = "n", keys = "<Leader>e", desc = "+Explore/Edit" },
--    { mode = "n", keys = "<Leader>f", desc = "+Find" },
--    { mode = "n", keys = "<Leader>t", desc = "+Terminal" },
--    { mode = "n", keys = "<Leader>g", desc = "+Git" },
--    { mode = "n", keys = "<Leader>u", desc = "+UI" },
--    { mode = "n", keys = "<Leader>o", desc = "+Obsidian" },
--    { mode = "n", keys = "<Leader><Leader>", desc = "+Other" },
-- }

nmap_leader("qc", "<cmd>cclose<cr>")
nmap_leader("qo", "<cmd>copen<cr>")

nmap_leader("oS", "<cmd>Obsidian search<cr>")
nmap_leader("os", "<cmd>Obsidian quick_switch<cr>")
nmap_leader("on", "<cmd>Obsidian new<cr>")
nmap_leader("ow", "<cmd>Obsidian workspace<cr>")
nmap_leader("O", "<cmd>Obsidian<cr>")

-- u for "Neovim UI and highlights"
nmap_leader("ui", vim.show_pos, "Inspect Pos")
nmap_leader("uI", "<cmd>InspectTree<cr>", "Inspect Tree")

nmap_leader("go", function()
   MiniDiff.toggle_overlay(0)
end, "Toggle Minidiff Overlay")

-- t is for 'Terminal'
nmap_leader("tT", "<Cmd>horizontal term<CR>", "Terminal (horizontal)")
nmap_leader("tt", "<Cmd>vertical term<CR>", "Terminal (vertical)")

-- b is for 'Buffer'
local new_scratch_buffer = function()
   vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader("ba", "<Cmd>b#<CR>", "alternate")
nmap_leader("bs", new_scratch_buffer, "scratch")
set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })
-- nmap_leader("bd", "<Cmd>lua MiniBufremove.delete()<CR>", "Delete")
-- nmap_leader("bD", "<Cmd>lua MiniBufremove.delete(0, true)<CR>", "Delete!")
-- nmap_leader("bw", "<Cmd>lua MiniBufremove.wipeout()<CR>", "Wipeout")
-- nmap_leader("bW", "<Cmd>lua MiniBufremove.wipeout(0, true)<CR>", "Wipeout!")

-- e is for 'Explore' and 'Edit'

local explore_quickfix = function()
   for _, win_id in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.fn.getwininfo(win_id).quickfix == 1 then
         return vim.cmd("cclose")
      end
   end
   vim.cmd("copen")
end

nmap_leader("ei", "<Cmd>edit $MYVIMRC<CR>", "init.lua")
nmap_leader("ep", "<Cmd>edit ~/Vaults/Notes/nvim.md<cr>", "plugins")
nmap_leader("eq", explore_quickfix, "quickfix")
-- nmap_leader("ed", "<Cmd>lua MiniFiles.open()<CR>", "Directory")
-- nmap_leader("ef", explore_at_file, "File directory")
-- nmap_leader("em", edit_plugin_file("30_mini.lua"), "MINI config")
-- nmap_leader("en", "<Cmd>lua MiniNotify.show_history()<CR>", "Notifications")
-- nmap_leader("eo", edit_plugin_file("10_options.lua"), "Options config")
-- nmap_leader("ep", edit_plugin_file("40_plugins.lua"), "Plugins config")

-- Create a new tab
nmap_leader("tn", "<Cmd>tabnew<CR>", "New [t]ab")
nmap_leader("tx", "<Cmd>tabclose<CR>", "E[x]clude tab")

-- Toggle showing the tabline
nmap_leader("tt", function()
   if vim.o.showtabline == 2 then
      vim.o.showtabline = 0
   else
      vim.o.showtabline = 2
   end
end, "Toggle [t]abs")

-- Navigate tabs
set("n", "]t", ":tabnext<CR>", { desc = "Next tab", silent = true })
set("n", "[t", ":tabprevious<CR>", { desc = "Previous tab", silent = true })

nmap_leader("/", function()
   Snacks.picker.grep()
end, "Grep")
nmap_leader("ff", function()
   Snacks.picker.files()
end, "Find files")

nmap_leader("fc", function()
   Snacks.picker.files({
      cwd = vim.fn.stdpath("config"),
   })
end, "Find Config File")

nmap_leader(",", function()
   Snacks.picker.buffers()
end, "Buffers")

nmap_leader("N", function()
   Snacks.notifier.show_history()
end, "Notification History")

nmap_leader("un", function()
   Snacks.notifier.hide()
end, "Hide Notifications")

-- stylua: ignore end

set("n", "<leader>fp", function()
   Snacks.picker.projects()
end, { desc = "Find Prject" })

set("n", "<leader>fR", function()
   Snacks.picker.resume()
end, { desc = "Resume" })

-- NOTE: `:bro ol`
set("n", "<leader>fr", function()
   Snacks.picker.recent()
end, { desc = "Recent" })

set("n", "<leader>.", function()
   Snacks.scratch()
end, { desc = "Scratch Pad" })

set("n", "<leader>fp", function()
   Snacks.picker.projects()
end, { desc = "Projects" })

set("n", "<leader>sm", function()
   Snacks.picker.marks()
end, { desc = "Marks" })

set("n", "<leader>gb", function()
   Snacks.picker.git_branches()
end, { desc = "Git branches" })

set("n", "<leader>P", function()
   Snacks.picker()
end, { desc = "All pickers" })
