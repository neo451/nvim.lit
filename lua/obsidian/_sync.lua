local log = require("obsidian.log")

local M = {}

vim.g.obsidian_sync_status = ""
local sync_proc = {}

local sync_log = {}
local sync_status = {}

local sync_icons = {
   synced = "󰸞",
   syncing = "󰑓",
   paused = "󰏤",
   disconnected = "󰲁",
   -- resume = "󰐊",
   -- history = "󰄉",
   -- log = "󰉫",
   -- deleted = "󰆴",
   -- settings = "󰒓",
}

local group = {
   synced = "DiagnosticOk",
   syncing = "DiagnosticWarn",
   paused = "DiagnosticInfo",
}

function M.status_color()
   local workspace = Obsidian and Obsidian.workspace or nil
   local key = workspace and tostring(workspace.root) or nil
   local kind = key and sync_status[key] or nil

   vim.g._obsidian_sync_status = kind
   vim.g.obsidian_sync_status = (kind and sync_icons[kind]) or ""

   local hl = group[kind]
   return hl or "DiagnosticInfo"
end

local function set_status(workspace, kind)
   local key = tostring(workspace.root)
   sync_status[key] = kind

   local current = Obsidian and Obsidian.workspace or nil
   if not current or tostring(current.root) ~= key then
      return
   end

   vim.g._obsidian_sync_status = kind
   vim.g.obsidian_sync_status = (kind and sync_icons[kind]) or ""
end

local function append_log(workspace, message)
   if not message or message == "" then
      return
   end

   local key = tostring(workspace.root)
   if not sync_log[key] then
      sync_log[key] = {}
   end

   local ts = os.date("%Y-%m-%d %H:%M")
   local lines = vim.split(message, "\n")

   for _, line in ipairs(lines) do
      if line and line ~= "" then
         if line == "Fully synced" then
            set_status(workspace, "synced")
         elseif line:lower():find("paused", 1, true) then
            set_status(workspace, "paused")
         else
            set_status(workspace, "syncing")
         end
         local entry = string.format("%s - %s", ts, line)
         table.insert(sync_log[key], entry)
      end
   end
end

local function stop_sync(workspace)
   if workspace and not workspace.root then
      workspace = nil
   end

   if not workspace then
      for path, proc in pairs(sync_proc) do
         pcall(function()
            proc:kill(15)
         end)

         sync_proc[path] = nil
         sync_status[path] = nil
      end
      vim.g._obsidian_sync_status = nil
      vim.g.obsidian_sync_status = ""
      return
   end

   local key = tostring(workspace.root)
   if not sync_proc[key] then
      return
   end

   pcall(function()
      sync_proc[key]:kill(15)
   end)

   sync_proc[key] = nil
   set_status(workspace, nil)
end

local function make_handler(workspace)
   return function(err, line)
      if err then
         log.err(err)
         append_log(workspace, tostring(err))
      end
      if not line then
         return
      end
      line = vim.trim(line)
      if line == "" then
         return
      end
      append_log(workspace, line)
   end
end

vim.api.nvim_create_autocmd("VimLeavePre", {
   group = vim.api.nvim_create_augroup("obsidian-sync", { clear = true }),
   callback = function()
      -- TODO: stop all
      stop_sync()
   end,
})

local function start_sync(workspace)
   workspace = workspace or Obsidian.workspace
   local key = tostring(workspace.root)
   local handler = make_handler(workspace)

   sync_proc[key] = vim.system({ "ob", "sync", "--continuous" }, {
      cwd = tostring(workspace.root),
      stderr = handler,
      stdout = handler,
   }, function(out)
      if sync_proc[key] ~= nil then
         sync_proc[key] = nil
         set_status(workspace, nil)
      end

      if out.code ~= 0 then
         log.err("obsidian sync exited", out)
         append_log(workspace, string.format("obsidian sync exited with code %s", tostring(out.code)))
      end
   end)
end

M.start = function(workspace)
   workspace = workspace or Obsidian.workspace
   stop_sync(workspace)
   start_sync(workspace)
end

M.stop = function(workspace)
   workspace = workspace or Obsidian.workspace
   local key = tostring(workspace.root)

   if sync_proc[key] ~= nil then
      sync_proc[key]:kill(19) -- SIGSTOP
      set_status(workspace, "paused")
   else
      log.warn("No sync process to pause")
   end
end

M.open_log = function(workspace)
   workspace = workspace or Obsidian.workspace
   local key = tostring(workspace.root)
   local buf = vim.api.nvim_create_buf(false, true)
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, sync_log[key] or {})
   vim.bo[buf].modifiable = false
   vim.api.nvim_buf_set_name(buf, "Obsidian Sync Log")
   vim.api.nvim_set_current_buf(buf)
   vim.keymap.set("n", "q", function()
      vim.api.nvim_buf_delete(buf, { force = true })
   end, { buffer = buf, silent = true })
end

M.menu = function()
   vim.ui.select({ "Start Sync", "Pause Sync", "View Sync Log" }, {
      prompt = "Obsidian Sync",
   }, function(choice)
      if choice == "Start Sync" then
         M.start()
      elseif choice == "Pause Sync" then
         M.stop()
      elseif choice == "View Sync Log" then
         M.open_log()
      end
   end)
end

return M
