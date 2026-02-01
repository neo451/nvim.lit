local util = require("obsidian.util")
local log = require("obsidian.log")
local api = require("obsidian.api")
local spotify = require("spotify")

local function html_unescape(s)
   -- small, practical subset
   s = s:gsub("&amp;", "&")
   s = s:gsub("&lt;", "<")
   s = s:gsub("&gt;", ">")
   s = s:gsub("&quot;", '"')
   s = s:gsub("&#39;", "'")
   return s
end

local function is_url(s)
   return type(s) == "string" and s:match("^https?://")
end

local function parse_title(html)
   if not html or html == "" then
      return nil
   end

   -- Normalize newlines a bit for simpler patterns
   local h = html:gsub("\r\n", "\n")

   local function meta_content(pattern)
      local content = h:match(pattern)
      if content then
         content = vim.trim(html_unescape(content))
         if content ~= "" then
            return content
         end
      end
   end

   -- og:title (property=) can appear in different attribute orders
   local og = meta_content("<meta[^>]-property=[\"']og:title[\"'][^>]-content=[\"'](.-)[\"'][^>]->")
      or meta_content("<meta[^>]-content=[\"'](.-)[\"'][^>]-property=[\"']og:title[\"'][^>]->")

   if og then
      return og
   end

   local tw = meta_content("<meta[^>]-name=[\"']twitter:title[\"'][^>]-content=[\"'](.-)[\"'][^>]->")
      or meta_content("<meta[^>]-content=[\"'](.-)[\"'][^>]-name=[\"']twitter:title[\"'][^>]->")

   if tw then
      return tw
   end

   local t = h:match("<title[^>]*>(.-)</title>")
   if t then
      t = vim.trim(html_unescape(t:gsub("%s+", " ")))
      if t ~= "" then
         return t
      end
   end

   return nil
end

local function fallback_title_from_url(url)
   -- simple fallback: last path segment or host
   local host = url:match("^https?://([^/%?#]+)") or url
   local last = url:match("^https?://[^/]+/(.-)$")
   if last and last ~= "" then
      last = last:gsub("[?#].*$", "")
      last = last:gsub("/+$", "")
      local seg = last:match("([^/]+)$")
      if seg and seg ~= "" then
         seg = seg:gsub("[-_]+", " ")
         return seg
      end
   end
   return host
end

local function fetch_html(url)
   local cmd = {
      "curl",
      "-fsSL",
      "--compressed",
      "-m",
      "15",
      url,
   }

   local out = vim.system(cmd, { text = true }):wait()
   if out.code ~= 0 then
      return nil, ("curl failed (%d): %s"):format(out.code, vim.trim(out.stderr or ""))
   end
   return out.stdout, nil
end

local function handle_weblink(url)
   local html, err = fetch_html(url)
   if err then
      local title = fallback_title_from_url(url)
      return title
   end

   local title = parse_title(html) or fallback_title_from_url(url)
   title = title:gsub("%]", "\\]")
   return ("[%s](%s)"):format(title, url)
end

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

local function handle_path(path, callback, phase)
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
      callback({ link }, phase)
   else
      log.err("Failed to handle local file")
   end
end

local attachment = require("obsidian.attachment")

local function fetch_remote_file(url, basename)
   local vault_attachment_path = api.resolve_attachment_path(basename)
   local out = vim.system({ "curl", url, "-o", vault_attachment_path }):wait(50000)
   if out.code ~= 0 then
      vim.notify("failed to copy attachment to vault " .. out.stderr)
      return
   end
end

local function handle_remote_resource_as_attachment(url)
   local basename = vim.fs.basename(url)

   local choice = api.confirm("How to handle remote file", "&Attach\n&Embed\n&Link")
   local link

   if choice == "Link" then
      link = ("![%s](%s)"):format(basename, url)
   elseif choice == "Attach" then
      fetch_remote_file(url, basename)
      link = ("[%s](%s)"):format(basename, util.urlencode(basename, { keep_path_sep = true }))
   elseif choice == "Embed" then
      fetch_remote_file(url, basename)
      link = ("![%s](%s)"):format(basename, util.urlencode(basename, { keep_path_sep = true }))
   end

   return link
end

local function handle_link(url, callback, phase)
   local link
   if vim.startswith(url, "https://open.spotify.com/") then
      link = spotify.markdown_link(url)
   elseif attachment.is_attachment_path(url) then
      link = handle_remote_resource_as_attachment(url)
   else
      link = handle_weblink(url)
   end
   if link then
      return callback({ link }, phase)
   else
      log.err("Failed to handle remote link")
   end
end

return function()
   vim.paste = (function(overridden)
      return function(lines, phase)
         if vim.b.obsidian_buffer then
            -- TODO: check clipboard is image
            local line = lines[1]
            if is_url(line) then
               return handle_link(line, overridden, phase)
            elseif looks_like_path(line) then
               return handle_path(line, overridden, phase)
            end
         end
         return overridden(lines, phase)
      end
   end)(vim.paste)
end
