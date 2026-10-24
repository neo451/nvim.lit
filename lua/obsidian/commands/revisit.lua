local api = require("obsidian.api")
local date = require("obsidian.date")
local daily = require("obsidian.daily")
local log = require("obsidian.log")
local Note = require("obsidian.note")

local function add_revisit(timestamp)
   local current_note = Note.from_buffer(0)
   if not current_note.path or not api.path_is_note(current_note.path) then
      log.err("Revisit must be run from a note in the active Obsidian workspace")
      return
   end

   local daily_note = daily.daily({ date = timestamp })
   if not daily_note:exists() then
      daily_note:write()
   end

   daily_note:insert_text("- [ ] " .. current_note:format_link(), {
      section = { header = "Entries", level = 2 },
      placement = "top",
      on_section_missing = "create",
   })

   log.info("Added revisit task to %s", tostring(daily_note.path:vault_relative_path()))
end

return function(data)
   local arg = vim.trim(data.args or "")
   if arg == "" then
      require("obsidian.resolvers").resolve("date", {
         intent = "revisit",
         cadence = "daily",
      }, function(result)
         if result and result.timestamp then
            add_revisit(result.timestamp)
         end
      end)
      return
   end

   local parsed, err = date.parse(arg)
   if not parsed then
      log.err("Invalid date '%s' (expected a date such as YYYY-MM-DD)%s", arg, err and (": " .. err) or "")
      return
   end

   add_revisit(os.time(parsed))
end
