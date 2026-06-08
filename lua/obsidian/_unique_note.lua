local M = {}

local function write_loaded_note_buffer(path, log)
   local target = tostring(path)
   for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buf) == target and vim.bo[buf].modified then
         local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
            vim.cmd.write()
         end)

         if not ok then
            log.warn("unique_note: failed to save daily note before appending link: " .. tostring(err))
         end
         return
      end
   end
end

local function today_daily_note(log)
   local note = require("obsidian.daily").today()
   write_loaded_note_buffer(note.path, log)

   if not note.path:exists() then
      note:write()
   end

   return require("obsidian.note").from_file(note.path)
end

function M.create_and_append(title)
   local log = require("obsidian.log")

   title = title or require("obsidian.api").input("Unique note title")
   if not title or vim.trim(title) == "" then
      log.info("Aborted")
      return
   end
   title = vim.trim(title)

   local note = require("obsidian.unique").new_unique_note(nil, {
      title = title,
      aliases = { title },
   })

   if not note then
      return
   end

   local daily_note = today_daily_note(log)
   daily_note:insert_text("- " .. note:format_link({ label = title }), {
      section = { header = "TIL", level = 2 },
      placement = "bot",
      on_section_missing = "create",
   })

   note:open({ sync = true })
   return note
end

function M.command(data)
   local title = data and data.args ~= "" and data.args or nil
   M.create_and_append(title)
end

return M
