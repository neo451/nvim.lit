---@enum obsidian.mimetypes
local supported_types = {
   html = "text/html",

   -- attachments
   markdown = "text/markdown",
   -- "application/octet-stream",
   canvas = "application/json",
   avif = "image/avif",
   bmp = "image/bmp",
   gif = "image/gif",
   jpeg = "image/jpeg",
   png = "image/png",
   svg = "image/svg+xml",
   webp = "image/webp",
   flac = "audio/flac",
   -- mp4 = "audio/mp4",
   mpeg = "audio/mpeg",
   -- ogg = "audio/ogg",
   wav = "audio/wav",
   -- webm = "audio/webm",
   gpp = "video/3gpp",
   -- "video/x-matroska",
   -- "video/quicktime",
   mp4 = "video/mp4",
   ogg = "video/ogg",
   webm = "video/webm",
   pdf = "application/pdf",
}

local M = {}

local api = require("obsidian.api")
---check cmd lists the types of content in the clipboard TODO: not specific to image on other platforms
---@return string[]|?
local function get_list_command()
   local this_os = api.get_os()
   if this_os == "Linux" or this_os == "FreeBSD" then
      local display_server = os.getenv("XDG_SESSION_TYPE")
      if display_server == "x11" or display_server == "tty" then
         -- check_cmd = "xclip -selection clipboard -o -t TARGETS"
         return { "xclip", "-selection", "clipboard", "-o", "-t", "TARGETS" }
      elseif display_server == "wayland" then
         return { "wl-paste", "--list-types" }
      end
   elseif this_os == api.OSType.Darwin then
      return { "pngpaste", "-b", "2>&1" } -- TODO:?
   elseif this_os == api.OSType.Windows or this_os == api.OSType.Wsl then
      return { "powershell.exe", '"Get-Clipboard -Format Image"' }
   end
end

local CLIPBOARD_ERROR = "no shell commands available for clipboard integration, check `checkhealth obsidian"

---@return obsidian.mimetypes[]|?
function M.list_types()
   local cmds = assert(get_list_command(), CLIPBOARD_ERROR)
   local out = vim.system(cmds):wait()
   if out.code ~= 0 then
      return
   end
   return vim.split(out.stdout, "\n", { trimempty = true })
end

---@param mime_type obsidian.mimetypes
---@return string[]|?
local function get_get_command(mime_type)
   local this_os = api.get_os()
   if this_os == api.OSType.Linux or this_os == api.OSType.FreeBSD then
      local display_server = os.getenv("XDG_SESSION_TYPE")
      if display_server == "x11" or display_server == "tty" then
         return
      -- check_cmd = "xclip -selection clipboard -o -t TARGETS"
      elseif display_server == "wayland" then
         return { "wl-paste", "--type", mime_type }
      end
   elseif this_os == api.OSType.Darwin then
      return
   -- cmd = "pngpaste -b 2>&1"
   elseif this_os == api.OSType.Windows or this_os == api.OSType.Wsl then
      return
      -- cmd = 'powershell.exe "Get-Clipboard -Format Image"'
   end
end

---@return obsidian.mimetypes|nil
local function clipboard_has_supported_mimetype()
   local current_clipboard_types = M.list_types()

   for _, mime_type in ipairs(current_clipboard_types or {}) do
      if vim.list_contains(supported_types, mime_type) then
         return mime_type
      end
   end
end

---@param mime_type obsidian.mimetypes|?
function M.get_content(mime_type)
   mime_type = mime_type or clipboard_has_supported_mimetype()

   if not mime_type then
      return
   end

   local cmds = assert(get_get_command(mime_type), CLIPBOARD_ERROR)
   local out = vim.system(cmds):wait()
   if out.code ~= 0 then
      return
   end
   -- TODO: might be different per platform
   return vim.split(out.stdout, "\n", { trimempty = true })
end

-- vim.print(M.get_content(supported_types.html))

return M
