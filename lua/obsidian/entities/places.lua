local M = {}

local function trim(value)
   return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function M.decode_google_component(value)
   return vim.uri_decode((value or ""):gsub("+", " "))
end

function M.sanitize_filename(value)
   value = trim(value):gsub('[\\/:*?"<>|]', "-")
   value = value:gsub("%s+", " ")
   value = value:gsub("^%.*", "")
   return value
end

function M.parse_name(url)
   local raw = url:match("/place/([^/?#]+)")
   if not raw or raw == "" then
      return nil
   end

   local name = M.sanitize_filename(M.decode_google_component(raw))
   return name ~= "" and name or nil
end

function M.parse_coordinates(url)
   local latitude = url:match("!3d(-?%d+%.?%d*)")
   local longitude = url:match("!4d(-?%d+%.?%d*)")
   if latitude and longitude then
      return latitude, longitude
   end

   return url:match("@(-?%d+%.?%d*),(-?%d+%.?%d*)")
end

function M.parse_url(url)
   local latitude, longitude = M.parse_coordinates(url)
   return {
      name = M.parse_name(url),
      latitude = latitude,
      longitude = longitude,
   }
end

function M.is_google_maps_url(value)
   return value:match("^https?://[^%s]+/maps/") ~= nil
end

return M
