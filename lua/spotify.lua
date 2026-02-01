local M = {}

---@param url string
---@return "album" | "artist" | "track"
---@return string id
function M.parse(url)
   url = vim.trim(url)
   local parts = vim.split(url, "/")
   local t, id = parts[#parts - 1], parts[#parts]
   id = id:gsub("%?.*$", "")
   return t, id
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
      vim.notify("failed to get access token")
      return
   end

   local token = vim.json.decode(out.stdout).access_token

   return token
end

local state = {}

function M.query_api(query)
   if not state.token then
      state.token = get_access_token()
   end

   local out = vim.system({
      "curl",
      ("https://api.spotify.com/v1/%s"):format(query),
      "-H",
      ("Authorization: Bearer %s"):format(state.token),
   }):wait()

   if out.code ~= 0 then
      vim.notify("failed to make query")
      return
   end

   return vim.json.decode(out.stdout)
end

function M.markdown_link(url)
   local sp = require("spotify")
   local t, id = sp.parse(url)
   local out = sp.query_api(t .. "s/" .. id)
   local name
   if out then
      name = out.name
   else
      name = ("spotify:%s:%s"):format(t, id)
   end
   return ("[`%s`](spotify:%s:%s)"):format(name, t, id)
end

return M
