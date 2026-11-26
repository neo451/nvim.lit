local M = {}

function M.open()
   local standalone = vim.g.cliphist_standalone == 1

   vim.system({ "cliphist", "list" }, { text = true }, function(result)
      vim.schedule(function()
         if result.code ~= 0 then
            if (result.stderr or ""):match("please store something first") then
               vim.notify("Clipboard history is empty")
               if standalone then
                  vim.cmd("qa")
               end
            else
               vim.notify(result.stderr, vim.log.levels.ERROR)
            end
            return
         end

         local entries = {}
         for line in result.stdout:gmatch("[^\n]+") do
            local id, preview = line:match("^(%d+)\t(.*)$")
            if id then
               entries[#entries + 1] = { id = id, preview = preview }
            end
         end
         if #entries == 0 then
            vim.notify("Clipboard history is empty")
            if standalone then
               vim.cmd("qa")
            end
            return
         end

         -- Obsidian is normally lazy-loaded for Markdown; this picker also runs
         -- from a fresh Neovim process with no note open.
         vim.opt.runtimepath:append(vim.fn.expand("~/Plugins/obsidian.nvim"))
         local picker = require("obsidian.picker").get("snacks.picker")
         local chosen = false
         local view = picker.select(entries, {
            prompt = "Clipboard history",
            format_item = function(entry)
               return entry.preview
            end,
         }, function(selection)
            local entry = selection and selection[1]
            if not entry then
               return
            end
            chosen = true
            vim.system({ "cliphist", "decode", entry.id }, {}, function(decoded)
               if decoded.code ~= 0 then
                  vim.schedule(function()
                     vim.notify(decoded.stderr, vim.log.levels.ERROR)
                  end)
                  return
               end
               -- wl-copy infers MIME from the decoded bytes (including images).
               vim.system({ "wl-copy" }, { stdin = decoded.stdout }, function(copied)
                  vim.schedule(function()
                     if copied.code ~= 0 then
                        vim.notify(copied.stderr, vim.log.levels.ERROR)
                     elseif standalone then
                        vim.cmd("qa")
                     end
                  end)
               end)
            end)
         end)

         if standalone then
            view.opts.on_close = function()
               -- Obsidian closes the picker before invoking its selection callback.
               vim.schedule(function()
                  if not chosen then
                     vim.cmd("qa")
                  end
               end)
            end
         end
      end)
   end)
end

return M
