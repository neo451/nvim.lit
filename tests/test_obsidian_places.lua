local new_set, eq = MiniTest.new_set, MiniTest.expect.equality

local places = require("obsidian.commands.places")

local T = new_set()

T["parse_name()"] = new_set()

T["parse_name()"]["decodes Google Maps place names with encoded ampersands"] = function()
   local url =
      "https://www.google.com/maps/place/Crossbones+Graveyard+%26+Garden+of+Remembrance/@51.5039022,-0.0960019,17z/data=!3m1!4b1!4m6!3m5!1s0x487603580470db99:0x8b5fa8052736dcd7!8m2!3d51.5039022!4d-0.093427!16s%2Fg%2F1jkxs7h78?entry=ttu&g_ep=EgoyMDI2MDYwMy4xIKXMDSoASAFQAw%3D%3D"

   eq(places.parse_name(url), "Crossbones Graveyard & Garden of Remembrance")
end

T["parse_name()"]["decodes plus-separated place names"] = function()
   local url =
      "https://www.google.com/maps/place/Secret+Intelligence+Service+(MI6)/@51.4873944,-0.1226733,17z/data=!4m6!3m5!1s0x4876058c72be3d8b:0x70db48696b522a49!8m2!3d51.4872742!4d-0.1243899!16s%2Fg%2F11s0wdfgx4?entry=ttu"

   eq(places.parse_name(url), "Secret Intelligence Service (MI6)")
end

T["parse_coordinates()"] = new_set()

T["parse_coordinates()"]["prefers place coordinates from data segment"] = function()
   local url =
      "https://www.google.com/maps/place/Secret+Intelligence+Service+(MI6)/@51.4873944,-0.1226733,17z/data=!4m6!3m5!1s0x4876058c72be3d8b:0x70db48696b522a49!8m2!3d51.4872742!4d-0.1243899!16s%2Fg%2F11s0wdfgx4?entry=ttu"
   local lat, lng = places.parse_coordinates(url)

   eq(lat, "51.4872742")
   eq(lng, "-0.1243899")
end

T["parse_coordinates()"]["falls back to viewport coordinates"] = function()
   local url = "https://www.google.com/maps/place/Foo/@51.1,-0.2,17z/"
   local lat, lng = places.parse_coordinates(url)

   eq(lat, "51.1")
   eq(lng, "-0.2")
end

return T
