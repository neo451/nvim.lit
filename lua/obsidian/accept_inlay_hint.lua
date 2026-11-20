local M = {}

function M.accept_previous_inlay_hint()
   if not vim.lsp.inlay_hint or type(vim.lsp.inlay_hint.get) ~= "function" then
      return false
   end

   local bufnr = vim.api.nvim_get_current_buf()
   local win = vim.api.nvim_get_current_win()
   local cursor = vim.api.nvim_win_get_cursor(win)
   local cursor_position = { line = cursor[1] - 1, character = cursor[2] }
   ---@type lsp.InlayHint[]
   local hints = {}

   local function position_before_or_at(left, right)
      return left.line < right.line or (left.line == right.line and left.character <= right.character)
   end

   for _, item in ipairs(vim.lsp.inlay_hint.get({ bufnr = bufnr })) do
      local client = vim.lsp.get_client_by_id(item.client_id)
      local hint = item.inlay_hint
      local range = type(hint.data) == "table" and hint.data.range or nil
      if
         client
         and client.name == "obsidian-ls"
         and type(range) == "table"
         and range.start
         and range["end"]
         and position_before_or_at(range["end"], cursor_position)
      then
         hints[#hints + 1] = hint
      end
   end

   if #hints == 0 then
      return false
   end

   table.sort(hints, function(left, right)
      local left_end = left.data.range["end"]
      local right_end = right.data.range["end"]
      return left_end.line > right_end.line
         or (left_end.line == right_end.line and left_end.character > right_end.character)
   end)

   local namespace = vim.api.nvim_create_namespace("accept-previous-inlay-hint")
   local cursor_mark =
      vim.api.nvim_buf_set_extmark(bufnr, namespace, cursor_position.line, cursor_position.character, {})
   for _, hint in ipairs(hints) do
      local start = hint.data.range.start
      local moved = pcall(vim.api.nvim_win_set_cursor, win, { start.line + 1, start.character })
      if moved then
         vim.schedule(function()
            if not vim.api.nvim_buf_is_valid(bufnr) then
               return
            end

            if hint.label[1].command then
               local command = hint.label[1].command
               local f = vim.lsp.commands[command.command]
               if f ~= nil then
                  f(command, {})
               end
            end

            local position = vim.api.nvim_buf_get_extmark_by_id(bufnr, namespace, cursor_mark, {})
            if #position == 2 and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == bufnr then
               vim.api.nvim_win_set_cursor(win, { position[1] + 1, position[2] })
            end
            vim.api.nvim_buf_del_extmark(bufnr, namespace, cursor_mark)
         end)
         return true
      end
   end

   vim.api.nvim_win_set_cursor(win, cursor)
   vim.api.nvim_buf_del_extmark(bufnr, namespace, cursor_mark)
   return false
end

return M
