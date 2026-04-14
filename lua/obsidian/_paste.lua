local util = require("obsidian.util")
local log = require("obsidian.log")
local api = require("obsidian.api")
local spotify = require("spotify")

-- TODO: don't error if just normal text
-- TODO: abort option

-- Unescape common shell-style backslash escapes from drag&drop paths:
--   /a/b/Churchill\ BRIEF\ Memo.pdf  ->  /a/b/Churchill BRIEF Memo.pdf
local function unescape_shell_path(s)
   s = (s or ""):gsub("^%s+", ""):gsub("%s+$", "")

   -- If the terminal/GUI wrapped it in quotes, strip them.
   s = s:gsub('^"(.*)"$', "%1")
   s = s:gsub("^'(.*)'$", "%1")

   -- Turn "\x" into "x" (covers "\ " "\(" "\[" etc.)
   s = s:gsub("\\(.)", "%1")

   return s
end

---Build a markdown link from a drag&drop path.
---@param path string  -- possibly shell-escaped path
---@return string md_link
local function format_uri_link(path)
   local name = vim.fs.basename(path)
   local encoded_path = util.urlencode(path, { keep_path_sep = true })
   local file_uri = "file://" .. encoded_path
   local md = string.format("[%s](%s)", name, file_uri)
   return md
end

--- Heuristic: does `s` look like a filesystem path?
--- Supports: absolute/relative Unix, Windows drive, UNC, and "has separators".
---@param s string?
---@return boolean
local function looks_like_path(s)
   if type(s) ~= "string" then
      return false
   end

   -- trim
   s = s:match("^%s*(.-)%s*$")
   if s == "" then
      return false
   end

   -- Reject obviously-not-a-path things (URLs, mailto, etc.)
   if s:match("^%a[%w+.-]*://") or s:match("^mailto:") then
      return false
   end

   -- Unix absolute: /foo or ~/foo
   if s:sub(1, 1) == "/" or s:sub(1, 2) == "~/" then
      return true
   end

   -- Windows drive: C:\foo or C:/foo
   if s:match("^[A-Za-z]:[\\/].+") then
      return true
   end

   return false
end

local function copy_local_file(path)
   local basename = vim.fs.basename(path)
   local vault_attachment_path = api.resolve_attachment_path(basename)
   if not vim.uv.fs_stat(path) then
      vim.notify("attachment file not exist")
      return
   end
   local ok, err = vim.uv.fs_copyfile(path, vault_attachment_path)
   if not ok then
      vim.notify("failed to copy attachment to vault " .. err)
      return
   end
end

local function format_attachment_link(path)
   local basename = vim.fs.basename(path)
   -- TODO: follow link.style, link.format
   local location = util.urlencode(basename, { keep_path_sep = true })
   return string.format("[%s](%s)", basename, location)
end

local function handle_path(path)
   path = unescape_shell_path(path)
   local link
   local choice = api.confirm("How to handle file", "&Attach\n&Embed\n&Link")
   if choice == "Link" then
      link = format_uri_link(path)
   elseif choice == "Attach" then
      copy_local_file(path)
      link = format_attachment_link(path)
   elseif choice == "Embed" then
      copy_local_file(path)
      link = "!" .. format_attachment_link(path)
   end
   if link then
      vim.api.nvim_put({ link }, "c", true, true)
   else
      log.err("Failed to handle local file")
   end
end

local attachment = require("obsidian.attachment")

local function handle_link(url)
   local link
   if vim.startswith(url, "https://open.spotify.com/") then
      link = spotify.markdown_link(url)
   elseif attachment.is_attachment_path(url) then
      link = require("obsidian._paste.remote_attachment")(url)
   else
      link = require("obsidian._paste.weblink")(url)
   end
   if link then
      vim.api.nvim_put({ link }, "c", true, true)
   else
      log.err("Failed to handle remote link")
   end
end

local function paste(lines)
   local line = lines[1]
   if vim.tbl_isempty(lines) or type(line) ~= "string" then
      return false
   end
   local is_uri, scheme = util.is_uri(line)
   -- TODO: check clipboard is image
   if is_uri and (scheme == "http" or scheme == "https") then
      handle_link(line)
      return true
   elseif looks_like_path(line) then
      handle_path(line)
      return true
   else
      return false
   end
end

return function()
   -- vim.paste = (function(overridden)
   --    return function(lines, phase)
   --       if vim.b.obsidian_buffer and paste(lines) then
   --          return
   --       end
   --       return overridden(lines, phase)
   --    end
   -- end)(vim.paste)
end
