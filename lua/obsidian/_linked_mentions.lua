local Path = require("obsidian.path")

---@type table<string, obsidian.BacklinkMatch[]>
local linked_mentions_cache = {}

---@param match obsidian.BacklinkMatch
---@return string, integer, integer, string
local function backlink_sort_key(match)
   local rel_path = Path.new(match.path):vault_relative_path() or tostring(match.path)
   return rel_path, match.line or 0, match.start or 0, match.text or ""
end

---@param matches obsidian.BacklinkMatch[]
---@return obsidian.BacklinkMatch[]
local function sort_backlink_matches(matches)
   table.sort(matches, function(a, b)
      local a_path, a_line, a_start, a_text = backlink_sort_key(a)
      local b_path, b_line, b_start, b_text = backlink_sort_key(b)

      if a_path ~= b_path then
         return a_path < b_path
      elseif a_line ~= b_line then
         return a_line < b_line
      elseif a_start ~= b_start then
         return a_start < b_start
      else
         return a_text < b_text
      end
   end)

   return matches
end

return function(note, update)
   local path = tostring(note.path)
   if update or linked_mentions_cache[path] == nil then
      linked_mentions_cache[path] = sort_backlink_matches(note:backlinks({}))
   end
   local matches = linked_mentions_cache[path]

   if #matches == 0 then
      return {}
   end

   local lines = { "Linked Mentions", "" }
   for _, match in ipairs(matches) do
      local rel_path = Path.new(match.path):vault_relative_path() or tostring(match.path)
      lines[#lines + 1] = string.format("%s: %s", rel_path, match.text or "")
   end

   return lines
end
