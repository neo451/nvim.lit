local M = {}

local ACTION = "note_media_section_link"

local function write_loaded_note_buffer(path, log)
   local target = tostring(path)
   for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_get_name(buf) == target and vim.bo[buf].modified then
         local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
            vim.cmd.write()
         end)

         if not ok then
            log.warn("media-db: failed to save daily note before appending link: " .. tostring(err))
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

local function register_action()
   local media_db = require("obsidian.media-db")
   local media_actions = require("obsidian.media-db.actions")

   if media_actions.get(ACTION) then
      return
   end

   media_db.register_action(ACTION, function(model, ctx)
      local log = require("obsidian.log")
      local note_model = media_actions.ensure_details(model)

      local ok, media_note_or_err = pcall(media_db.create_note, note_model)
      if not ok then
         log.error("media-db: failed to create note: " .. tostring(media_note_or_err))
         return
      end

      local media_note = media_note_or_err
      local daily_note = today_daily_note(log)
      daily_note:insert_text("- " .. media_note:format_link(), {
         section = { header = "Media", level = 2 },
         placement = "bot",
         on_section_missing = "create",
      })

      vim.cmd.edit(vim.fn.fnameescape(tostring(media_note.path)))
   end)
end

function M.search()
   register_action()

   local media_actions = require("obsidian.media-db.actions")
   local ctx = {
      selector = "type",
      prompt_title = "Media Search Results",
   }

   require("obsidian.media-db").run_action(ACTION, ctx)
end

return M
