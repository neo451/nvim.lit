--- A simple implementation of vim.ui.select using a floating window.
--- <https://github.com/neovim/neovim/discussions/38231>
return function(items, opts, on_choice)
   if #items == 0 then
      on_choice(nil)
      return
   end

   local bufnr = vim.api.nvim_create_buf(false, true)
   local lines = {}
   local max_length = 0
   local format_item = opts.format_item or tostring
   local title = opts.prompt or "Select one of:"
   for _, item in ipairs(items) do
      local line = format_item(item)
      table.insert(lines, line)
      max_length = math.max(max_length, #line)
   end
   vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
   vim.bo[bufnr].modifiable = false

   local width = math.min(math.max(max_length, #title), math.floor(vim.o.columns * 0.6))
   local height = math.min(#items, math.floor(vim.o.lines * 0.6))
   local win = vim.api.nvim_open_win(bufnr, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2) - 1,
      col = math.floor((vim.o.columns - width) / 2),
      style = "minimal",
      border = vim.o.winborder == "" and "single" or vim.o.winborder,
      title = title,
   })
   vim.wo[win].winfixbuf = true
   vim.wo[win].cursorline = true

   vim.keymap.set("n", "<CR>", function()
      local cur_row = vim.api.nvim_win_get_cursor(0)[1]
      vim.api.nvim_buf_delete(bufnr, {})
      on_choice(items[cur_row], cur_row)
   end, { buffer = bufnr })

   vim.api.nvim_create_autocmd("WinClosed", {
      buffer = bufnr,
      callback = function()
         vim.api.nvim_buf_delete(bufnr, {})
         on_choice(nil)
      end,
   })
end
