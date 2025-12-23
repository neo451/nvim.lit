local Note = require("obsidian.note")
local api = require("obsidian.api")
local util = require("obsidian.util")
local log = require("obsidian.log")

return function()
   local album_name = api.input("Album_name: ")

   if not album_name then
      return
   end

   if util.contains_invalid_characters(album_name) then
      log.err("contains_invalid_characters")
   end

   local note = Note.create({
      id = "Music/" .. album_name,
   })

   -- TODO: sync version should also return bufnr
   note:open({
      callback = function(bufnr)
         note:write_to_buffer({
            bufnr = bufnr,
            template = "album",
         })
      end,
   })
end
