local M = {}

local subcommands = {
   view = true,
   open = "view",
   create = true,
   c = "create",
   new = "create",
   refresh = true,
   reload = "refresh",
   source = true,
   edit = "source",
   views = true,
   pick = "views",
   next = true,
   prev = true,
   previous = "prev",
}

local function trim(s)
   return vim.trim(tostring(s or ""))
end

local function split_first(arg)
   arg = trim(arg)
   if arg == "" then
      return nil, ""
   end

   local first, rest = arg:match("^(%S+)%s*(.-)$")
   return first, trim(rest)
end

local function normalize_command(cmd)
   local action = subcommands[cmd]
   if action == true then
      return cmd
   end
   return action
end

function M.command(data)
   local base = require("obsidian._base")
   local arg = trim(data.args)
   local bufnr = vim.api.nvim_get_current_buf()
   local table_bufnr = vim.bo[bufnr].filetype == "obsidian-base-table" and bufnr or nil

   if arg == "" then
      if vim.bo.filetype == "obsidian-base-table" then
         base.refresh()
      else
         base.view()
      end
      return
   end

   local first, rest = split_first(arg)
   local action = normalize_command(first)

   -- Backwards compatible: `:Obsidian base My View` opens a view named "My View".
   if action == nil then
      base.view({ view = arg, bufnr = table_bufnr })
      return
   end

   if action == "view" then
      base.view({ view = rest ~= "" and rest or nil, bufnr = table_bufnr })
   elseif action == "create" then
      base.create({ view = rest ~= "" and rest or vim.b.obsidian_base_view })
   elseif action == "refresh" then
      base.refresh({ view = rest ~= "" and rest or nil })
   elseif action == "source" then
      base.open_source()
   elseif action == "views" then
      base.pick_view()
   elseif action == "next" then
      base.next_view()
   elseif action == "prev" then
      base.prev_view()
   end
end

local function matching_view_names(arg_lead)
   local ok, names = pcall(require("obsidian._base").view_names)
   if not ok then
      return {}
   end

   local out = {}
   for _, name in ipairs(names) do
      if vim.startswith(name, arg_lead) then
         out[#out + 1] = name
      end
   end
   return out
end

function M.complete(arg_lead, cmdline)
   arg_lead = arg_lead or ""
   cmdline = cmdline or ""

   local args = cmdline:match("%S+%s+%S+%s+(.*)$") or ""
   local first = split_first(args)
   local action = normalize_command(first)

   if action == "view" or action == "create" or action == "refresh" then
      return matching_view_names(arg_lead)
   end

   local out = {}
   for cmd in pairs(subcommands) do
      if vim.startswith(cmd, arg_lead) then
         out[#out + 1] = cmd
      end
   end

   -- Also complete view names at top level for the compatibility form.
   vim.list_extend(out, matching_view_names(arg_lead))
   table.sort(out)
   return out
end

do
   local ok, base = pcall(require, "obsidian._base")
   if ok then
      -- base.setup_autocmd()
   end
end

return setmetatable(M, {
   __call = function(_, data)
      return M.command(data)
   end,
})
