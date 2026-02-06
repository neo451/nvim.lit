-- Simple slot-based file navigation with cursor position persistence
-- Stores slots per-project (git root) or globally (non-git directories)

_G.GLOBAL_SLOTS = _G.GLOBAL_SLOTS or {}
_G.PROJ_SLOTS = _G.PROJ_SLOTS or {}

----------------------------------------------------------
-- Context: git root detection and storage paths
----------------------------------------------------------

local function get_git_root()
   local ok, out = pcall(vim.fn.systemlist, "git rev-parse --show-toplevel 2>/dev/null")

   if not ok or not out or #out == 0 or out[1] == "" then
      return nil
   end

   return vim.fn.fnamemodify(out[1], ":p")
end

local function get_storage_path()
   local base_dir = vim.fn.stdpath("data") .. "/project_argslots"

   vim.fn.mkdir(base_dir, "p")

   local root = get_git_root()
   if root then
      return base_dir .. "/" .. vim.fn.sha256(root) .. ".json"
   else
      return base_dir .. "/global.json"
   end
end

local function get_slots()
   return get_git_root() and _G.PROJ_SLOTS or _G.GLOBAL_SLOTS
end

local function set_slots(new_slots)
   if get_git_root() then
      _G.PROJ_SLOTS = new_slots
   else
      _G.GLOBAL_SLOTS = new_slots
   end
end

----------------------------------------------------------
-- Persistence: load/save slots
----------------------------------------------------------

local function load_slots()
   local path = get_storage_path()
   local slots = {}

   if vim.fn.filereadable(path) == 1 then
      local content = table.concat(vim.fn.readfile(path), "\n")
      local ok, decoded = pcall(vim.fn.json_decode, content)

      if ok and type(decoded) == "table" then
         for _, entry in ipairs(decoded) do
            if type(entry) == "table" and entry.file then
               table.insert(slots, entry)
            end
         end
      end
   end

   set_slots(slots)
end

local function save_slots()
   local path = get_storage_path()
   local json = vim.fn.json_encode(get_slots())

   vim.fn.writefile({ json }, path)
end

----------------------------------------------------------
-- Core operations
----------------------------------------------------------

local function open_slot(n)
   local entry = get_slots()[n]

   if not entry or not entry.file then
      vim.notify("Slot " .. n .. " is empty", vim.log.levels.WARN)

      return
   end

   vim.cmd.edit(vim.fn.fnameescape(entry.file))

   if entry.row and entry.col then
      vim.api.nvim_win_set_cursor(0, { entry.row, entry.col })
   end
end

local function add_to_slots()
   local file = vim.api.nvim_buf_get_name(0)

   if file == "" or file:match("^argslots://") then
      return
   end

   file = vim.fn.fnamemodify(file, ":p")

   local cursor = vim.api.nvim_win_get_cursor(0)
   local new_entry = { file = file, row = cursor[1], col = cursor[2] }
   local slots = get_slots()

   -- Update if exists, otherwise append
   local is_existing_entry = false

   for i, entry in ipairs(slots) do
      if entry.file and vim.fn.fnamemodify(entry.file, ":p") == file then
         slots[i] = new_entry
         is_existing_entry = true

         break
      end
   end

   if not is_existing_entry then
      table.insert(slots, new_entry)
   end

   set_slots(slots)
   save_slots()
end

----------------------------------------------------------
-- Keymaps
----------------------------------------------------------

vim.keymap.set("n", "<leader>a", add_to_slots, { desc = "Add file to slots" })
vim.keymap.set("n", "<leader>h", function()
   open_slot(1)
end, { desc = "Open Slot 1" })
vim.keymap.set("n", "<leader>j", function()
   open_slot(2)
end, { desc = "Open Slot 2" })
vim.keymap.set("n", "<leader>k", function()
   open_slot(3)
end, { desc = "Open Slot 3" })
vim.keymap.set("n", "<leader>l", function()
   open_slot(4)
end, { desc = "Open Slot 4" })

----------------------------------------------------------
-- Slots editor UI
----------------------------------------------------------

local slots_win_id = nil

local function close_floating_window()
   if slots_win_id and vim.api.nvim_win_is_valid(slots_win_id) then
      vim.api.nvim_win_close(slots_win_id, true)
   end

   slots_win_id = nil

   vim.notify("")
end

local function create_floating_window(buf, lines)
   local width = math.floor(vim.o.columns * 0.6)
   local height = math.min(#lines + 4, math.floor(vim.o.lines * 0.8))
   local row = math.floor((vim.o.lines - height) / 2)
   local col = math.floor((vim.o.columns - width) / 2)

   vim.api.nvim_buf_set_name(buf, "argslots://edit")
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)

   vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
   vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
   vim.api.nvim_set_option_value("buftype", "acwrite", { buf = buf })
   vim.api.nvim_set_option_value("filetype", "argslots", { buf = buf })

   local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = row,
      col = col,
      border = "rounded",
      title = { { " Harpoon ", "NormalFloat" } },
      title_pos = "center",
      style = "minimal",
   })
   vim.api.nvim_set_option_value("number", true, { win = win })

   return win
end

vim.keymap.set("n", "<leader>e", function()
   -- Toggle close if already open
   if slots_win_id and vim.api.nvim_win_is_valid(slots_win_id) then
      close_floating_window()
      return
   end

   local slots = get_slots()

   -- Build buffer content (just file paths)
   local lines = {}
   for _, entry in ipairs(slots) do
      if entry and entry.file then
         table.insert(lines, entry.file)
      end
   end

   if #lines == 0 then
      lines = { "" }
   end

   local buf = vim.api.nvim_create_buf(false, true)

   slots_win_id = create_floating_window(buf, lines)

   -- Save handler
   local function save_and_close()
      if not vim.api.nvim_buf_is_valid(buf) then
         return
      end

      local new_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local new_slots = {}

      for _, line in ipairs(new_lines) do
         local path = line:match("^%s*(.-)%s*$")
         if path ~= "" then
            -- Preserve cursor position if file already exists
            local existing = nil
            for _, entry in ipairs(slots) do
               if entry.file == path then
                  existing = entry
                  break
               end
            end

            table.insert(new_slots, existing or { file = path, row = 1, col = 0 })
         end
      end

      set_slots(new_slots)
      save_slots()
      close_floating_window()
   end

   -- Keymaps
   vim.keymap.set("n", "<Esc>", close_floating_window, { buffer = buf, nowait = true, silent = true })

   vim.api.nvim_create_autocmd("BufWriteCmd", {
      buffer = buf,
      callback = save_and_close,
   })

   vim.api.nvim_create_autocmd("BufLeave", {
      buffer = buf,
      callback = close_floating_window,
   })
end, { desc = "Edit slots" })

----------------------------------------------------------
-- Auto-load/save on startup and directory change
----------------------------------------------------------

vim.api.nvim_create_autocmd("VimEnter", {
   callback = load_slots,
})

vim.api.nvim_create_autocmd("DirChanged", {
   callback = load_slots,
})

vim.api.nvim_create_autocmd("VimLeavePre", {
   callback = save_slots,
})
