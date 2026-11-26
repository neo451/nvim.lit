-- Show the highest-severity diagnostic on the cursor line in UI2's message area.
-- Inspired by https://github.com/neovim/neovim/pull/39871 and
-- https://github.com/yochem/dotfiles/blob/main/nvim/plugin/diagnostics.lua
local api = vim.api
local message_id = "nvim.diy.cursor_diagnostic"
local shown = false

local function update()
   local diagnostics = vim.diagnostic.get(0, { lnum = api.nvim_win_get_cursor(0)[1] - 1 })
   table.sort(diagnostics, function(a, b)
      return a.severity < b.severity
   end)

   local d = diagnostics[1]
   if not d then
      if shown then
         -- Replace only our own message, not someone else's echo.
         api.nvim_echo({ { "" } }, false, { id = message_id, kind = "echo" })
         shown = false
      end
      return
   end

   local severity = vim.diagnostic.severity[d.severity]
   local name = severity:sub(1, 1) .. severity:sub(2):lower()
   api.nvim_echo({
      { name, "Diagnostic" .. name },
      { ": " },
      { d.message:match("^[^\n]*") },
      { (" (%s)"):format(d.source or "unknown"), "LineNr" },
   }, false, { id = message_id, kind = "echo" })
   shown = true
end

local group = api.nvim_create_augroup("DiyUi2Diagnostics", { clear = true })
api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "DiagnosticChanged", "BufEnter", "WinEnter" }, {
   group = group,
   callback = update,
})

update()
