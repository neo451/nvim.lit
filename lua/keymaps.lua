local set = vim.keymap.set

local pinyin_search = require("qol.pinyin_search")
-- `/` remains a familiar search entry point, but understands both full pinyin
-- and 小鹤双拼. `:PinyinSearch` and the Lua API are available too.
pinyin_search.setup()
set("n", "/", pinyin_search.search, { desc = "Pinyin search" })
set("n", "?", function()
   pinyin_search.search({ direction = -1 })
end, { desc = "Pinyin search backwards" })

local diy_search = require("qol.search")
set({ "n", "x" }, diy_search.config.trigger, diy_search.query_browser, { remap = true })

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

set("i", "jk", "<esc>l")
vim.keymap.set({ "n", "t" }, "<leader>T", "<cmd>lua Snacks.terminal()<cr>")

-- super help docs everywhere
set("n", "vK", "<C-\\><C-N><Cmd>help!<CR>")

set("n", "<leader>C", function()
   vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled({ bufnr = 0 }), { bufnr = 0 })

   vim.notify(vim.lsp.codelens.is_enabled() and "Code Lens Enabled" or "Code Lens Disabled")
end)

set("n", "<leader>H", function()
   vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), { bufnr = 0 })
   vim.notify(vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }) and "Inlay Hint Enabled" or "Inlay Hint Disabled")
end)

set("n", "gra", function()
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

-- mini version control!
set("n", "ycc", function()
   return "yy" .. vim.v.count1 .. "gcc']p"
end, { remap = true, expr = true })

-- fix previous spell error
set("i", "<C-l>", "<Esc>[s1z=`]a")

-- Builtin completion: open the menu, then use <C-n>/<C-p> to move.
set("i", "<C-n>", function()
   if vim.fn.pumvisible() == 1 then
      return "<C-n>"
   end
   vim.lsp.completion.get()
   return ""
end, { expr = true, desc = "Completion: next item" })

set("i", "<C-p>", function()
   if vim.fn.pumvisible() == 1 then
      return "<C-p>"
   end
   vim.lsp.completion.get()
   return ""
end, { expr = true, desc = "Completion: previous item" })

-- Copy/paste with system clipboard
set({ "n", "x" }, "gY", '"+y$', { desc = "Copy to system clipboard" })
set({ "n", "x" }, "gy", '"+y', { desc = "Copy to system clipboard" })
set("n", "gp", '"+p', { desc = "Paste from system clipboard" })
-- - Paste in Visual with `P` to not copy selected text (`:h v_P`)
set("x", "gp", '"+P', { desc = "Paste from system clipboard" })

set("n", "<leader>U", "<cmd>Undotree<cr>", { desc = "Toggle UndoTree" })

set("n", "<End>", function()
   local file = vim.api.nvim_buf_get_name(0)
   if file == "" then
      vim.cmd("restart")
   else
      vim.cmd("restart edit " .. vim.fn.fnameescape(file))
   end
end)

--search within visual selection - this is magic
set("x", "/", "<Esc>/\\%V")

-- better J: keep cursor in place
set("n", "J", "mzJ`z:delmarks z<cr>")

-- https://github.com/mhinz/vim-galore#saner-behavior-of-n-and-n
set("n", "n", function()
   if pinyin_search.next(1) then
      return
   end
   vim.cmd.normal({ args = { vim.v.searchforward == 1 and "n" or "N" }, bang = true })
end, { desc = "Next Search Result" })
set("x", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
set("o", "n", "'Nn'[v:searchforward]", { expr = true, desc = "Next Search Result" })
set("n", "N", function()
   if pinyin_search.next(-1) then
      return
   end
   vim.cmd.normal({ args = { vim.v.searchforward == 1 and "N" or "n" }, bang = true })
end, { desc = "Prev Search Result" })
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
   if vim.startswith(base, "test_") then
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

nmap_leader("oS", "<cmd>Obsidian search<cr>")
nmap_leader("os", "<cmd>Obsidian quick_switch<cr>")
nmap_leader("od", "<cmd>Obsidian today<cr>")
nmap_leader("on", "<cmd>Obsidian new<cr>")
nmap_leader("ou", "<cmd>Obsidian unique_note<cr>")
nmap_leader("ow", "<cmd>Obsidian workspace<cr>")
nmap_leader("om", "<cmd>Obsidian media_search<cr>")

nmap_leader("O", "<cmd>Obsidian<cr>")
nmap_leader("oc", require("obsidian._actions").capture_to_daily)

nmap_leader("go", function()
   MiniDiff.toggle_overlay(0)
end, "Toggle Minidiff Overlay")

nmap_leader("gg", function()
   Snacks.lazygit()
end, "Open Lazygit")

nmap_leader("gd", function()
   vim.cmd("CodeDiff main")
end, "Open Lazygit")

-- b is for 'Buffer'
local new_scratch_buffer = function()
   vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, true))
end

nmap_leader("ba", "<Cmd>b#<CR>", "alternate")
nmap_leader("bs", new_scratch_buffer, "scratch")
set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev Buffer" })
set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next Buffer" })

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

set("n", "<leader>fp", function()
   Snacks.picker.projects()
end, { desc = "Find Project" })

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

set("n", "<leader>P", function()
   Snacks.picker({})
end, { desc = "All pickers" })
