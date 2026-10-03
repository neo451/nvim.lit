local M = {}

local function next_character(text, byte)
   local first = text:byte(byte)
   if first < 0x80 then
      return text:sub(byte, byte), 1
   elseif first < 0xE0 then
      return text:sub(byte, byte + 1), 2
   elseif first < 0xF0 then
      return text:sub(byte, byte + 2), 3
   elseif first < 0xF8 then
      return text:sub(byte, byte + 3), 4
   end
   return text:sub(byte, byte), 1
end

local function characters(text)
   local result = {}
   local byte = 1
   while byte <= #text do
      local character, width = next_character(text, byte)
      result[#result + 1] = {
         text = character,
         start_byte = byte,
         end_byte = byte + width,
      }
      byte = byte + width
   end
   return result
end

local function spellings(value)
   if type(value) == "table" then
      return value
   elseif type(value) == "string" then
      return { value }
   end
   return {}
end

local function normalize_query(query)
   return query:lower():gsub("[%s%-']", "")
end

local function match_from(chars, index, query, query_index, spelling_table)
   if query_index > #query then
      return index - 1
   end
   if not chars[index] then
      return nil
   end

   local entry = spelling_table[chars[index].text]
   if not entry then
      return nil
   end

   for _, code in ipairs(spellings(entry)) do
      local remaining = #query - query_index + 1
      if remaining < #code then
         if query:sub(query_index) == code:sub(1, remaining) then
            return index
         end
      elseif query:sub(query_index, query_index + #code - 1) == code then
         local ending = match_from(chars, index + 1, query, query_index + #code, spelling_table)
         if ending then
            return ending
         end
      end
   end
   return nil
end

local function add_match(matches, seen, line_number, start_byte, end_byte)
   local key = start_byte .. ":" .. end_byte
   if seen[key] then
      return
   end
   seen[key] = true
   matches[#matches + 1] = {
      line = line_number,
      start_col = start_byte - 1,
      end_col = end_byte - 1,
   }
end

function M.find_in_line(line, line_number, query, spelling_tables)
   query = normalize_query(query)
   if query == "" then
      return {}
   end

   local chars = characters(line)
   local matches = {}
   local seen = {}
   local literal_line = line:lower()
   local literal_start = 1
   while true do
      local start_byte, end_byte = literal_line:find(query, literal_start, true)
      if not start_byte then
         break
      end
      add_match(matches, seen, line_number, start_byte, end_byte + 1)
      literal_start = end_byte + 1
   end

   for index, character in ipairs(chars) do
      for _, spelling_table in ipairs(spelling_tables) do
         local ending = match_from(chars, index, query, 1, spelling_table)
         if ending then
            add_match(matches, seen, line_number, character.start_byte, chars[ending].end_byte)
         end
      end
   end

   table.sort(matches, function(left, right)
      if left.start_col == right.start_col then
         return left.end_col < right.end_col
      end
      return left.start_col < right.start_col
   end)
   return matches
end

function M.find(buffer, query, schemes)
   local spelling_tables = {}
   local tables = require("qol.pinyin_search.tables")
   for _, scheme in ipairs(schemes) do
      spelling_tables[#spelling_tables + 1] = tables.resolve(scheme)
   end

   local matches = {}
   local lines = vim.api.nvim_buf_get_lines(buffer, 0, -1, false)
   for line_number, line in ipairs(lines) do
      local line_matches = M.find_in_line(line, line_number, query, spelling_tables)
      for _, match in ipairs(line_matches) do
         matches[#matches + 1] = match
      end
   end
   return matches
end

return M
