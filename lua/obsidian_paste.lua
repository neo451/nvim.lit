local util = require("obsidian.util")

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

-- Percent-encode a string for use in a URI path segment.
-- Keeps RFC3986 "unreserved" + "/" so absolute paths remain readable.
local function uri_encode_path(path)
   return (path:gsub("([^%w%-%._~/%:])", function(ch)
      return string.format("%%%02X", string.byte(ch))
   end))
end

---Build a markdown link from a drag&drop path.
---@param raw string  -- possibly shell-escaped path
---@return string md_link
local function md_link_from_path(raw)
   local escaped = unescape_shell_path(raw)
   local name = vim.fs.basename(escaped)
   local encoded_path = util.urlencode(escaped, { keep_path_sep = true })
   local md = string.format("[%s](%s)", name, encoded_path)
   return md
end
--
-- return function()
--    vim.paste = (function(og)
--       return function(lines, phase)
--          if vim.b.obsidian_buffer then
--             -- TODO: use find_ref?
--             -- TODO: look like path
--             local line = lines[1]
--             if not util.is_url(line) then
--                local link = md_link_from_path(line)
--                lines[1] = link
--             end
--          end
--          og(lines, phase)
--       end
--    end)(vim.paste)
-- end
