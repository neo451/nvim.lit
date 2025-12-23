local Note = require("obsidian.note")
local api = require("obsidian.api")
local util = require("obsidian.util")
local log = require("obsidian.log")

---@param url string
---@return "album" | "artist"
---@return string id
local function pasre_spotify_url(url)
   url = vim.trim(url)
   -- TODO: check if open.spotify.com
   local parts = vim.split(url, "/")

   return parts[#parts - 1], parts[#parts]
end

local function get_access_token()
   local client_id = os.getenv("SPOTIFY_CLIENT_ID")
   local client_secret = os.getenv("SPOTIFY_CLIENT_SECRET")
   local auth = "Authorization: Basic " .. vim.base64.encode(string.format("%s:%s", client_id, client_secret))

   local out = vim.system({
      "curl",
      "-X",
      "POST",
      "https://accounts.spotify.com/api/token",
      "-H",
      auth,
      "-H",
      "Content-Type: application/x-www-form-urlencoded",
      "-d",
      "grant_type=client_credentials",
   }):wait()

   if out.code ~= 0 then
      log.err("failed to get access token")
      return
   end

   local token = vim.json.decode(out.stdout).access_token

   return token
end

local function get_album_by_id(id, token)
   local out = vim.system({
      "curl",
      -- "-X",
      -- "POST",
      ("https://api.spotify.com/v1/albums/%s"):format(id),
      "-H",
      ("Authorization: Bearer %s"):format(token),
      -- "-H",
      -- "Content-Type: application/x-www-form-urlencoded",
      -- "-d",
      -- "grant_type=client_credentials",
   }):wait()

   if out.code ~= 0 then
      log.err("failed to make album search")
      return
   end

   local album = vim.json.decode(out.stdout)
   local artist = album.artists[1].name
   return { name = album.name, artist = artist }
end

local get_link = function(link)
   local t, id = pasre_spotify_url(link)

   if not t then
      return
   end

   local token = get_access_token()

   if not token then
      log.err("failed to fetch token")
      return
   end

   return get_album_by_id(id, token)
end

return function()
   local link = api.input("Spotify Link: ")

   if not link then
      return
   end

   local res = get_link(link)

   if not res then
      return
   end

   if util.contains_invalid_characters(res.name) then
      log.err("contains_invalid_characters, refactor!")
      return
   end

   local note = Note.create({
      id = "Music/" .. res.name,
   })

   -- TODO: sync version should also return bufnr
   note:open({
      callback = function(bufnr)
         vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, {
            "---",
            "artist: " .. res.artist,
            ("image: http://localhost:9000/%s/%s"):format(util.urlencode(res.artist), util.urlencode(res.name)),
            "---",
         })
         vim.cmd("w")
      end,
   })
end
