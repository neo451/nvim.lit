local picker = require("obsidian.picker")

return function()
   local attachments = {}

   ---@param dir obsidian.Path
   local function walk(dir)
      local attachment_dir = dir / assert(Obsidian.opts.attachments.folder)

      if attachment_dir and attachment_dir:exists() then
         for p, type in vim.fs.dir(tostring(attachment_dir)) do
            if type == "file" then
               local path = tostring(attachment_dir / p)
               attachments[#attachments + 1] = path
            end
         end
      end

      for p, type in vim.fs.dir(tostring(dir)) do
         if type == "directory" then
            local subdir = dir / p
            walk(subdir)
         end
      end
   end
   walk(Obsidian.dir)

   vim.ui.select(attachments, {
      format_item = function(item)
         return vim.fs.basename(item)
      end,
      preview_item = function(item)
         -- local buf = vim.api.nvim_create_buf(false, true)
         local buf = vim.fn.bufadd(item)
         vim.fn.bufload(buf)
         vim.bo[buf].buflisted = false

         return { buf = buf }
      end,
   }, function(item, idx)
      if not item then
         return
      end
   end)

   -- picker.pick(attachments)
end
