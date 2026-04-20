local hl = function(group)
   return vim.api.nvim_get_hl(0, {
      name = group,
      link = false,
      create = false,
   })
end

local set_hl_groups = function()
   local base = hl("StatusLine")

   for group, opts in pairs({
      ModeNormal = { fg = base.bg, bg = hl("StatusLine").fg },
      ModePending = { fg = base.bg, bg = hl("Comment").fg },
      ModeVisual = { fg = base.bg, bg = hl("SpecialKey").fg },
      ModeInsert = { fg = base.bg, bg = hl("DiffAdded").fg },
      ModeCommand = { fg = base.bg, bg = hl("Number").fg },
      ModeReplace = { fg = base.bg, bg = hl("Constant").fg },
      Bold = { fg = base.fg, bg = base.bg, bold = true },
      Dim = { fg = hl("LineNr").fg, bg = base.bg },
   }) do
      group = "StatusLine" .. group
      vim.api.nvim_set_hl(0, group, opts)
      opts.fg, opts.bg = opts.bg, opts.fg
      vim.api.nvim_set_hl(0, group .. "Inverted", opts)
   end
end

-- Compile and apply our custom highlights
set_hl_groups()

-- Re-compile statusline colours when the colorscheme changes
vim.api.nvim_create_autocmd("ColorScheme", {
   group = vim.api.nvim_create_augroup("my_statusline", {}),
   desc = "Re-apply statusline highlights on colorscheme change",
   callback = set_hl_groups,
})

local mode_component = function()
   -- Note: termcodes \19 and \22 are ^S and ^V
   --- stylua: ignore
   local mode_settings = {
      ["n"] = { name = "NORMAL", hl = "Normal" },
      ["no"] = { name = "OP-PENDING", hl = "Pending" },
      ["nov"] = { name = "OP-PENDING", hl = "Pending" },
      ["noV"] = { name = "OP-PENDING", hl = "Pending" },
      ["no\22"] = { name = "OP-PENDING", hl = "Pending" },
      ["niI"] = { name = "NORMAL", hl = "Normal" },
      ["niR"] = { name = "NORMAL", hl = "Normal" },
      ["niV"] = { name = "NORMAL", hl = "Normal" },
      ["nt"] = { name = "NORMAL", hl = "Normal" },
      ["ntT"] = { name = "NORMAL", hl = "Normal" },
      ["v"] = { name = "VISUAL", hl = "Visual" },
      ["vs"] = { name = "VISUAL", hl = "Visual" },
      ["V"] = { name = "V-LINE", hl = "Visual" },
      ["Vs"] = { name = "V-LINE", hl = "Visual" },
      ["\22"] = { name = "V-BLOCK", hl = "Visual" },
      ["\22s"] = { name = "V-BLOCK", hl = "Visual" },
      ["s"] = { name = "SELECT", hl = "Insert" },
      ["S"] = { name = "S-LINE", hl = "Normal" },
      ["\19"] = { name = "S-BLOCK", hl = "Normal" },
      ["i"] = { name = "INSERT", hl = "Insert" },
      ["ic"] = { name = "INSERT", hl = "Insert" },
      ["ix"] = { name = "INSERT", hl = "Insert" },
      ["R"] = { name = "REPLACE", hl = "Replace" },
      ["Rc"] = { name = "REPLACE", hl = "Replace" },
      ["Rx"] = { name = "REPLACE", hl = "Replace" },
      ["Rv"] = { name = "V-REPLACE", hl = "Replace" },
      ["Rvc"] = { name = "V-REPLACE", hl = "Replace" },
      ["Rvx"] = { name = "V-REPLACE", hl = "Replace" },
      ["c"] = { name = "COMMAND", hl = "Command" },
      ["cv"] = { name = "EX", hl = "Command" },
      ["ce"] = { name = "EX", hl = "Command" },
      ["r"] = { name = "REPLACE", hl = "Normal" },
      ["rm"] = { name = "MORE", hl = "Normal" },
      ["r?"] = { name = "CONFIRM", hl = "Normal" },
      ["!"] = { name = "SHELL", hl = "Normal" },
      ["t"] = { name = "TERMINAL", hl = "Command" },
   }

   local mode = mode_settings[vim.fn.mode()] or {}

   return table.concat({
      "%#StatuslineMode" .. mode.hl .. "Inverted" .. "#",
      "%#StatuslineMode" .. mode.hl .. "#" .. mode.name,
      "%#StatuslineMode" .. mode.hl .. "Inverted" .. "#",
   })
end

local statusline_bufnr = function()
   return vim.api.nvim_win_get_buf(vim.g.statusline_winid or 0)
end

local obsidian_sync = function()
   local ok, sync = pcall(require,"obsidian.sync.status")
   if not ok then
      return ""
   end
   local s = sync.component()
   return s == "" and "" or (s .. " ")
end

local obsidian_status = function()
   local buf = statusline_bufnr()
   if not vim.b[buf].obsidian_buffer then
      return ""
   end
   local s = vim.b[buf].obsidian_status
   if not s then
      return ""
   end
   return s
end

local rime_statusline = function()
   local s = vim.g.rime_enabled and "ㄓ" or ""
   return s == "" and "" or (s .. " ")
end

local diff_component = function()
   local buf = statusline_bufnr()
   local summary = vim.b[buf].minidiff_summary
   if not summary then
      return ""
   end
   local parts = {}
   if (summary.add or 0) > 0 then
      parts[#parts + 1] = "%#DiffAdded#+" .. summary.add
   end
   if (summary.change or 0) > 0 then
      parts[#parts + 1] = "%#DiffChanged#~" .. summary.change
   end
   if (summary.delete or 0) > 0 then
      parts[#parts + 1] = "%#DiffRemoved#-" .. summary.delete
   end
   if #parts == 0 then
      return ""
   end
   return " " .. table.concat(parts, " ") .. "%#StatusLine# "
end

local diagnostic_component = function()
   -- Add some padding around the actual info; need to use patterns so
   -- highlights are also applied to the padding.
   return vim.diagnostic.status(statusline_bufnr()):gsub("%w+:", " %0", 1):gsub("(:%d+)%%", "%1 %%")
end

vim.api.nvim_create_autocmd("User", {
   pattern = { "ObsidianSyncChanged", "MiniDiffUpdated" },
   command = "redrawstatus",
})

return {
   render = function()
      local active_win = vim.fn.win_getid()
      local status_win = vim.g.statusline_winid
      if status_win ~= active_win then
         return "Statusline for inactive windows"
      end
      return table.concat({
         mode_component(),
         diff_component(),
         "%=",
         diagnostic_component(),
         obsidian_status(),
         obsidian_sync(),
         rime_statusline(),
      })
   end,
}
