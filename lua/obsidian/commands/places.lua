local M = {}

M.PLACES_DIR = vim.fn.expand("~/Documents/Notes/Entities/")

local function trim(s)
   return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

function M.decode_google_component(s)
   return vim.uri_decode((s or ""):gsub("+", " "))
end

function M.sanitize_filename(s)
   return trim(s):gsub("/", "／")
end

function M.parse_name(url)
   local raw = url:match("/place/([^/?#]+)")
   if not raw or raw == "" then
      return nil
   end

   local name = M.sanitize_filename(M.decode_google_component(raw))
   if name == "" then
      return nil
   end
   return name
end

function M.parse_coordinates(url)
   local lat = url:match("!3d(-?%d+%.?%d*)")
   local lng = url:match("!4d(-?%d+%.?%d*)")
   if lat and lng then
      return lat, lng
   end

   lat, lng = url:match("@(-?%d+%.?%d*),(-?%d+%.?%d*)")
   return lat, lng
end

function M.parse_url(url)
   local lat, lng = M.parse_coordinates(url)
   return {
      name = M.parse_name(url),
      latitude = lat,
      longitude = lng,
   }
end

function M.command(data)
   local log = require("obsidian.log")
   local url = trim(data.args or "")
   if url == "" then
      url = require("obsidian.api").input("Google Maps URL")
      if not url or trim(url) == "" then
         log.info("Aborted")
         return
      end
      url = trim(url)
   end

   local name = M.parse_name(url)
   if not name then
      log.err("Could not parse place name from URL")
      return
   end

   local lat, lng = M.parse_coordinates(url)
   if not lat or not lng then
      log.err("Could not parse coordinates from URL")
      return
   end

   vim.fn.mkdir(M.PLACES_DIR, "p")
   local path = M.PLACES_DIR .. "/" .. name .. ".md"

   if vim.fn.filereadable(path) == 0 then
      vim.fn.writefile({
         "---",
         "coordinates:",
         string.format('  - "%s"', lat),
         string.format('  - "%s"', lng),
         "---",
      }, path)
   end

   vim.cmd.edit(vim.fn.fnameescape(path))
end

return setmetatable(M, {
   __call = function(_, data)
      return M.command(data)
   end,
})
