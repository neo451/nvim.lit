vim.api.nvim_set_hl(0, "TabLine", { bg = "NONE", fg = "#666666" })
vim.api.nvim_set_hl(0, "TabLineFill", { bg = "NONE" })

vim.api.nvim_set_hl(0, "TabLinePillActiveLeft", { fg = "#8aadf4", bg = "#1e1e2e" })
vim.api.nvim_set_hl(0, "TabLinePillActiveText", { fg = "#1e1e2e", bg = "#8aadf4" })
vim.api.nvim_set_hl(0, "TabLinePillActiveRight", { fg = "#8aadf4", bg = "#1e1e2e" })

vim.api.nvim_set_hl(0, "TabLinePillInactiveLeft", { fg = "#737994", bg = "#1e1e2e" })
vim.api.nvim_set_hl(0, "TabLinePillInactiveText", { fg = "#1e1e2e", bg = "#737994" })
vim.api.nvim_set_hl(0, "TabLinePillInactiveRight", { fg = "#737994", bg = "#1e1e2e" })

vim.o.tabline = "%!v:lua.PillTabline()"

function _G.PillTabline()
   local s = ""
   local tabs = vim.api.nvim_list_tabpages()
   local current = vim.api.nvim_get_current_tabpage()

   for i, tab in ipairs(tabs) do
      local is_active = (tab == current)

      local hl_left = is_active and "%#TabLinePillActiveLeft#" or "%#TabLinePillInactiveLeft#"
      local hl_text = is_active and "%#TabLinePillActiveText#" or "%#TabLinePillInactiveText#"
      local hl_right = is_active and "%#TabLinePillActiveRight#" or "%#TabLinePillInactiveRight#"

      s = s .. hl_left .. ""
      s = s .. hl_text .. " " .. i .. " "
      s = s .. hl_right .. ""
      s = s .. "%#TabLine# "
   end

   return s
end
