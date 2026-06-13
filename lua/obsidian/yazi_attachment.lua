local actions = require("obsidian.actions")
local attachment = require("obsidian.attachment")
local api = require("obsidian.api")

local yazi = function(opts)
   local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
   local tmp = vim.fn.tempname()
   local buf = vim.api.nvim_create_buf(false, true)
   local width = math.floor(vim.o.columns * 0.8)
   local height = math.floor(vim.o.lines * 0.8)
   local win = vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      width = width,
      height = height,
      style = "minimal",
      border = "rounded",
   })
   vim.fn.jobstart({ "yazi", "--chooser-file=" .. tmp }, {
      term = true,
      on_exit = function()
         vim.api.nvim_win_close(win, true)
         vim.api.nvim_buf_delete(buf, { force = true })
         if vim.uv.fs_stat(tmp) then
            local lines = vim.fn.readfile(tmp)
            if lines[1] then
               attachment.add(lines[1], { insert = opts.insert, bufnr = bufnr })
            end
         end
      end,
   })
   vim.cmd("startinsert")
end

actions.add_attachment = function(_, opts)
   opts = opts or {}
   vim.ui.select({ "Remote url", "Local path" }, {}, function(item)
      if item == "Remote url" then
         local input = api.input("Url", {})
         if not input then
            return
         end
         attachment.add(vim.trim(input), opts)
      else
         yazi(opts)
      end
   end)
end
