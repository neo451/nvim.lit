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

local function handle_link(url)
   local html, err = fetch_html(url)
   if err then
      local title = fallback_title_from_url(url)
      -- vim.notify("Inserted link (fallback title). Fetch failed: " .. err, vim.log.levels.WARN)
      return title
   end

   local title = parse_title(html) or fallback_title_from_url(url)
   -- Escape ']' in title for markdown link text
   title = title:gsub("%]", "\\]")
   return title
end

vim.paste = (function(overridden)
   return function(lines, phase)
      if vim.bo.filetype == "markdown" then
         if #lines == 1 and is_url(lines[1]) then
            local url = lines[1]
            local title = handle_link(url)
            local link = ("[%s](%s)"):format(title, url)
            return overridden({ link }, phase)
         end
      end
      return overridden(lines, phase)
   end
end)(vim.paste)
