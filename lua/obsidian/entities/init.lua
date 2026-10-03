local Note = require("obsidian.note")
local api = require("obsidian.api")
local log = require("obsidian.log")
local util = require("obsidian.util")

local places = require("obsidian.entities.places")

local M = {}

local defaults = {
   folder = "Entities",
   templates = {
      place = "entities/place.md",
      person = "entities/person.md",
      thing = "entities/thing.md",
   },
   geocoder = {
      url = "https://nominatim.openstreetmap.org/search",
      user_agent = "obsidian-entities.nvim/0.1",
   },
}

local config

local function trim(value)
   return vim.trim(value or "")
end

local function get_config()
   if not config then
      config = vim.deepcopy(defaults)
   end
   return config
end

local function workspace_root()
   return api.resolve_workspace_dir()
end

local function entities_dir()
   return workspace_root() / get_config().folder
end

local function valid_name(name)
   name = places.sanitize_filename(name)
   if name == "" then
      return nil
   end

   local valid = util.is_valid_filename(name)
   if not valid then
      return nil
   end
   return name
end

local function note_path(name)
   return entities_dir() / (name .. ".md")
end

local function open_existing(path)
   local note = Note.from_file(path)
   note:open({ sync = true })
   return note
end

local function aliases_for_place(item)
   local aliases = {}
   local seen = {}
   local primary = trim(item.name)

   for key, value in pairs(item.namedetails or {}) do
      if type(value) == "string" and trim(value) ~= "" and key ~= "name" then
         value = trim(value)
         if value ~= primary and not seen[value] then
            seen[value] = true
            aliases[#aliases + 1] = value
         end
      end
   end

   table.sort(aliases)
   return aliases
end

---@param kind string
---@param name string
---@param fields table<string, any>|nil
---@param aliases string[]|nil
---@return obsidian.Note, boolean
function M.create_note(kind, name, fields, aliases)
   local safe_name = valid_name(name)
   if not safe_name then
      error("Invalid entity name: " .. tostring(name))
   end

   local path = note_path(safe_name)
   if path:is_file() then
      return open_existing(path), false
   end

   local note = Note.create({
      id = safe_name,
      verbatim = true,
      dir = entities_dir(),
      aliases = aliases or {},
      template = get_config().templates[kind],
      scope = "entity",
   })
   note = note:write()

   note:add_field("type", kind)
   for key, value in pairs(fields or {}) do
      note:add_field(key, value)
   end
   note:save({ insert_frontmatter = true })
   note:open({ sync = true })

   log.info("Created %s entity '%s'", kind, safe_name)
   return note, true
end

---@param query string
---@param callback fun(results: table[]|nil, err: string|nil)
function M.search_places(query, callback)
   local cfg = get_config().geocoder
   local http = require("obsidian.media-db.http")

   http.get_json(cfg.url, {
      query = {
         q = query,
         format = "jsonv2",
         namedetails = 1,
         limit = 8,
      },
      headers = {
         ["User-Agent"] = cfg.user_agent,
         ["Accept-Language"] = "en",
      },
      timeout = 15,
   }, function(data, err)
      if not data then
         callback(nil, err)
         return
      end

      local results = {}
      for _, item in ipairs(data) do
         local latitude = tostring(item.lat or "")
         local longitude = tostring(item.lon or "")
         local display_name = trim(item.display_name)
         if latitude ~= "" and longitude ~= "" and display_name ~= "" then
            results[#results + 1] = {
               name = trim(item.name) ~= "" and trim(item.name) or display_name,
               display_name = display_name,
               latitude = latitude,
               longitude = longitude,
               namedetails = item.namedetails or {},
            }
         end
      end

      callback(results, nil)
   end)
end

---@param query string
---@param callback fun(note: obsidian.Note|nil, created: boolean|nil)
function M.create_place(query, callback)
   query = trim(query)
   if query == "" then
      return
   end

   if places.is_google_maps_url(query) then
      local parsed = places.parse_url(query)
      if parsed.name and parsed.latitude and parsed.longitude then
         local note, created = M.create_note("place", parsed.name, {
            coordinates = { parsed.latitude, parsed.longitude },
         })
         callback(note, created)
         return
      end
   end

   M.search_places(query, function(results, err)
      if not results or #results == 0 then
         if err then
            log.warn("Place lookup failed: %s", err)
         else
            log.warn("No place results for '%s'", query)
         end

         local fallback_name = places.sanitize_filename(query:gsub("^https?://", ""))
         local note, created = M.create_note("place", fallback_name, {})
         callback(note, created)
         if created then
            require("obsidian.entities.agent").run({
               kind = "place",
               query = query,
               path = tostring(note.path),
            })
         end
         return
      end

      vim.ui.select(results, {
         prompt = "Place",
         format_item = function(item)
            return item.name .. " — " .. item.display_name
         end,
      }, function(item)
         if not item then
            log.info("Aborted")
            return
         end

         local note, created = M.create_note("place", item.name, {
            coordinates = { item.latitude, item.longitude },
         }, aliases_for_place(item))
         callback(note, created)
      end)
   end)
end

---@param kind string
---@param query string
function M.create_person(kind, query)
   local note, created = M.create_note(kind, query, {})
   if created then
      require("obsidian.entities.agent").run({
         kind = kind,
         query = query,
         path = tostring(note.path),
      })
   end
end

function M.create_thing(query)
   M.create_note("thing", query, {})
end

---@param opts table|nil
function M.setup(opts)
   config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
   return M
end

function M.get_config()
   return get_config()
end

return M
