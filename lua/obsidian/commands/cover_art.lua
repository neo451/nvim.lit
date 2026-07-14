local function trim(s)
   return (s:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function sanitize_filename(s)
   s = trim(s or "")
   s = s:gsub('[%z/\\:*?"<>|]', "-")
   s = s:gsub("%s+", " ")
   s = s:gsub("^%.*", "")
   return s ~= "" and s or "cover-art"
end

local function image_extension(url)
   local path = (url or ""):gsub("[?#].*$", "")
   local ext = path:match("%.([%w]+)$")
   ext = ext and ext:lower() or "jpg"

   if vim.tbl_contains({ "jpg", "jpeg", "png", "webp", "gif" }, ext) then
      return ext
   end

   return "jpg"
end

local function cover_art_dir()
   local root = Obsidian and Obsidian.dir and tostring(Obsidian.dir) or vim.fn.getcwd()
   return vim.fs.joinpath(root, "CoverArt")
end

local function cover_art_basename(model, metadata)
   local title = metadata.title or model.title or "cover-art"
   return sanitize_filename(title)
end

local function download_cover_art(model)
   local mediaDB = require("obsidian.media-db")
   local detailed = mediaDB.actions.ensure_details(model)
   local metadata = mediaDB.to_frontmatter(detailed)
   local image = metadata.image

   if type(image) ~= "string" or trim(image) == "" then
      vim.notify("No cover art URL found", vim.log.levels.ERROR)
      return
   end

   local dir = cover_art_dir()
   vim.fn.mkdir(dir, "p")

   local filename = cover_art_basename(detailed, metadata) .. "." .. image_extension(image)
   local path = vim.fs.joinpath(dir, filename)

   vim.system({ "curl", "-fL", "-sS", "-o", path, image }, { text = true }, function(obj)
      vim.schedule(function()
         if obj.code ~= 0 then
            vim.notify(
               "Failed to download cover art: " .. (obj.stderr or obj.stdout or "curl failed"),
               vim.log.levels.ERROR
            )
            return
         end

         vim.notify("Downloaded cover art: " .. path, vim.log.levels.INFO)
      end)
   end)
end

---@param data obsidian.CommandArgs
return function(data)
   local mediaDB = require("obsidian.media-db")
   local query = (data.args and data.args ~= "") and data.args or nil

   mediaDB.search({
      query = query,
      selector = "none",
      types = { mediaDB.MediaType.Music },
      prompt = "Music Cover Art",
      on_select = download_cover_art,
   })
end
