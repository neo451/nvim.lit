local opencode = require("_opencode")
local api = require("obsidian.api")

local function refactor()
   local viz = api.get_visual_selection()
   local inst = api.input("Refactor", { default = "Generate a mermaid diagram for the selected code or current file" })

   local row = unpack(vim.api.nvim_win_get_cursor(0))

   local start_row = viz and viz.csrow or row
   local end_row = viz and viz.cerow

   local prompt = "Refactor the selected code or current file based on the following instructions."

   if inst and inst ~= "" then
      prompt = prompt .. "\n\nInstructions: " .. inst
   end

   prompt = prompt .. "\n\nFocus on clean markdown results, no explanations, only the refactored text."

   if viz then
      prompt = prompt .. "\n\nSelected Lines:\n" .. table.concat(viz, "\n")
   end

   vim.notify("Refactoring code with AI...", vim.log.levels.INFO, { title = "Inline Refactor" })

   opencode(prompt, {
      modle = "gpt-4o",
   }, function(output)
      if not output then
         vim.notify("No output from refactor", vim.log.levels.ERROR, { title = "Inline Refactor" })
         return
      end

      local bufnr = vim.api.nvim_get_current_buf()
      local lines = vim.split(output, "\n")
      end_row = end_row or row + #lines - 1

      -- Replace the current selection with the refactored code
      vim.api.nvim_buf_set_lines(bufnr, start_row, end_row, false, lines)
   end)
end

return {
   refactor = refactor,
}
