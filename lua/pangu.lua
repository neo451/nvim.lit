local M = {}

local ASCII_SPACE = 0x20
local ASCII_TAB = 0x09

local function code_in(code, ranges)
   for _, range in ipairs(ranges) do
      if code >= range[1] and code <= range[2] then
         return true
      end
   end
   return false
end

local cjk_ranges = {
   { 0x3040, 0x309f }, -- Hiragana
   { 0x30a0, 0x30ff }, -- Katakana
   { 0x3400, 0x4dbf }, -- CJK Extension A
   { 0x4e00, 0x9fff }, -- CJK Unified Ideographs
   { 0xac00, 0xd7af }, -- Hangul Syllables
   { 0xf900, 0xfaff }, -- CJK Compatibility Ideographs
   { 0x20000, 0x2a6df },
   { 0x2a700, 0x2b73f },
   { 0x2b740, 0x2b81f },
   { 0x2b820, 0x2ceaf },
   { 0x2ceb0, 0x2ebef },
   { 0x30000, 0x3134f },
}

---@param code integer
---@return boolean
local function is_cjk(code)
   return code_in(code, cjk_ranges)
end

---@param code integer
---@return boolean
local function is_cjk_left_boundary(code)
   return is_cjk(code)
end

---@param code integer
---@return boolean
local function is_cjk_right_boundary(code)
   return is_cjk(code)
end

---@param code integer
---@return boolean
local function is_space(code)
   return code == ASCII_SPACE or code == ASCII_TAB or code == 0x0a or code == 0x0d
end

---@param code integer
---@return boolean
local function is_ascii_core(code)
   return (code >= 0x30 and code <= 0x39) -- 0-9
      or (code >= 0x41 and code <= 0x5a) -- A-Z
      or (code >= 0x61 and code <= 0x7a) -- a-z
end

---@param code integer
---@return boolean
local function is_ascii_token_char(code)
   return is_ascii_core(code)
      or code == 0x5f -- _
      or code == 0x2b -- +
      or code == 0x2d -- -
      or code == 0x2e -- .
      or code == 0x2f -- /
      or code == 0x3a -- :
      or code == 0x25 -- %
      or code == 0x26 -- &
      or code == 0x3d -- =
end

---@param s string
---@return table[]
local function utf8_chars(s)
   local chars = {}
   local i = 1
   local len = #s

   while i <= len do
      local b1 = s:byte(i)
      local width = 1
      local code = b1

      if b1 >= 0xf0 and i + 3 <= len then
         local b2, b3, b4 = s:byte(i + 1), s:byte(i + 2), s:byte(i + 3)
         width = 4
         code = (b1 - 0xf0) * 0x40000 + (b2 - 0x80) * 0x1000 + (b3 - 0x80) * 0x40 + (b4 - 0x80)
      elseif b1 >= 0xe0 and i + 2 <= len then
         local b2, b3 = s:byte(i + 1), s:byte(i + 2)
         width = 3
         code = (b1 - 0xe0) * 0x1000 + (b2 - 0x80) * 0x40 + (b3 - 0x80)
      elseif b1 >= 0xc0 and i + 1 <= len then
         local b2 = s:byte(i + 1)
         width = 2
         code = (b1 - 0xc0) * 0x40 + (b2 - 0x80)
      end

      chars[#chars + 1] = { text = s:sub(i, i + width - 1), code = code }
      i = i + width
   end

   return chars
end

---@param chars table[]
---@param idx integer
---@return boolean
local function has_ascii_core_before(chars, idx)
   for i = idx, 1, -1 do
      local code = chars[i].code
      if is_ascii_core(code) then
         return true
      end
      if is_space(code) or is_cjk_left_boundary(code) or not is_ascii_token_char(code) then
         return false
      end
   end
   return false
end

---@param chars table[]
---@param idx integer
---@return boolean
local function has_ascii_core_after(chars, idx)
   for i = idx, #chars do
      local code = chars[i].code
      if is_ascii_core(code) then
         return true
      end
      if is_space(code) or is_cjk_right_boundary(code) or not is_ascii_token_char(code) then
         return false
      end
   end
   return false
end

---@param chars table[]
---@param idx integer
---@return boolean
local function needs_space(chars, idx)
   local left = chars[idx].code
   local right = chars[idx + 1].code

   if is_space(left) or is_space(right) then
      return false
   end

   if is_cjk_left_boundary(left) then
      return is_ascii_core(right)
   end

   if is_cjk_right_boundary(right) then
      return is_ascii_core(left) or (is_ascii_token_char(left) and has_ascii_core_before(chars, idx))
   end

   return false
end

---@param text string
---@return string
function M.spacing_text(text)
   if text == "" then
      return text
   end

   local chars = utf8_chars(text)
   local out = {}

   for i, char in ipairs(chars) do
      out[#out + 1] = char.text
      if chars[i + 1] and needs_space(chars, i) then
         out[#out + 1] = " "
      end
   end

   return table.concat(out)
end

---@param chunks table[]
---@return string
local function join_markdown_chunks(chunks)
   local out = {}

   for _, chunk in ipairs(chunks) do
      out[#out + 1] = chunk.text
   end

   return table.concat(out)
end

---@param best_start integer?
---@param best_end integer?
---@param start integer?
---@param finish integer?
---@return integer?, integer?
local function earlier_span(best_start, best_end, start, finish)
   if start and (not best_start or start < best_start) then
      return start, finish
   end
   return best_start, best_end
end

---@param text string
---@param pos integer
---@return integer?, integer?
local function find_dollar_span(text, pos)
   local start, finish, marker = text:find("(%$+)", pos)
   if not start then
      return nil, nil
   end

   local close_start, close_end = text:find(marker, finish + 1, true)
   if not close_start then
      return nil, nil
   end

   return start, close_end
end

---@param text string
---@param pos integer
---@return integer?, integer?
local function find_next_raw_span(text, pos)
   local best_start, best_end = text:find("%a[%w%+%.%-]*://%S+", pos)
   best_start, best_end = earlier_span(best_start, best_end, text:find("!%[%[.-%]%]", pos))
   best_start, best_end = earlier_span(best_start, best_end, text:find("%[%[.-%]%]", pos))
   best_start, best_end = earlier_span(best_start, best_end, text:find("!%b[]%b()", pos))
   best_start, best_end = earlier_span(best_start, best_end, text:find("%b[]%b()", pos))
   best_start, best_end = earlier_span(best_start, best_end, text:find("%b[]", pos))
   best_start, best_end = earlier_span(best_start, best_end, text:find("<!%-%-.-%-%->", pos))
   best_start, best_end = earlier_span(best_start, best_end, text:find("<[^%s][^>]->", pos))
   best_start, best_end = earlier_span(best_start, best_end, find_dollar_span(text, pos))

   return best_start, best_end
end

---@param chunks table[]
---@param text string
local function push_text_chunks(chunks, text)
   local pos = 1

   while true do
      local raw_start, raw_end = find_next_raw_span(text, pos)
      if not raw_start then
         chunks[#chunks + 1] = { kind = "text", text = M.spacing_text(text:sub(pos)) }
         break
      end

      chunks[#chunks + 1] = { kind = "text", text = M.spacing_text(text:sub(pos, raw_start - 1)) }
      chunks[#chunks + 1] = { kind = "raw", text = text:sub(raw_start, raw_end) }
      pos = raw_end + 1
   end
end

---@param line string
---@return string
function M.spacing_markdown_line(line)
   local chunks = {}
   local pos = 1

   while true do
      local tick_start, tick_end, ticks = line:find("(`+)", pos)
      if not tick_start then
         push_text_chunks(chunks, line:sub(pos))
         break
      end

      push_text_chunks(chunks, line:sub(pos, tick_start - 1))

      local close_start, close_end = line:find(ticks, tick_end + 1, true)
      if not close_start then
         push_text_chunks(chunks, line:sub(tick_start))
         break
      end

      chunks[#chunks + 1] = { kind = "raw", text = line:sub(tick_start, close_end) }
      pos = close_end + 1
   end

   return join_markdown_chunks(chunks)
end

---@param line string
---@return boolean
local function is_fence(line)
   return line:match("^%s*```") ~= nil or line:match("^%s*~~~") ~= nil
end

---@param lines string[]
---@return string[]
function M.format_lines(lines)
   local formatted = {}
   local in_fence = false
   local in_math_fence = false
   local in_frontmatter = false

   for i, line in ipairs(lines) do
      if i == 1 and line:match("^%s*%-%-%-%s*$") then
         in_frontmatter = true
         formatted[i] = line
      elseif in_frontmatter then
         formatted[i] = line
         if i > 1 and line:match("^%s*%-%-%-%s*$") then
            in_frontmatter = false
         end
      elseif is_fence(line) then
         formatted[i] = line
         in_fence = not in_fence
      elseif line:match("^%s*%$%$%s*$") then
         formatted[i] = line
         in_math_fence = not in_math_fence
      elseif in_fence or in_math_fence then
         formatted[i] = line
      else
         formatted[i] = M.spacing_markdown_line(line)
      end
   end

   return formatted
end

---@param text string
---@return string
function M.spacing_markdown(text)
   local has_trailing_newline = text:sub(-1) == "\n"
   local lines = vim.split(text, "\n", { plain = true })

   if has_trailing_newline then
      table.remove(lines)
   end

   local formatted = M.format_lines(lines)
   return table.concat(formatted, "\n") .. (has_trailing_newline and "\n" or "")
end

return M
