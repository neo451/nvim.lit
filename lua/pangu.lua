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

local cjk_open = {
   [0x3008] = true, -- 〈
   [0x300a] = true, -- 《
   [0x300c] = true, -- 「
   [0x300e] = true, -- 『
   [0x3010] = true, -- 【
   [0x3014] = true, -- 〔
   [0xff08] = true, -- （
   [0xff3b] = true, -- ［
   [0xff5b] = true, -- ｛
}

local cjk_close = {
   [0x3009] = true, -- 〉
   [0x300b] = true, -- 》
   [0x300d] = true, -- 」
   [0x300f] = true, -- 』
   [0x3011] = true, -- 】
   [0x3015] = true, -- 〕
   [0xff09] = true, -- ）
   [0xff3d] = true, -- ］
   [0xff5d] = true, -- ｝
}

local ascii_open = {
   [0x28] = true, -- (
   [0x5b] = true, -- [
   [0x7b] = true, -- {
   [0x3c] = true, -- <
}

local ascii_close = {
   [0x29] = true, -- )
   [0x5d] = true, -- ]
   [0x7d] = true, -- }
   [0x3e] = true, -- >
}

local ascii_prefix = {
   [0x23] = true, -- #
   [0x24] = true, -- $
   [0x40] = true, -- @
}

---@param code integer
---@return boolean
local function is_cjk(code)
   return code_in(code, cjk_ranges)
end

---@param code integer
---@return boolean
local function is_cjk_left_boundary(code)
   return is_cjk(code) or cjk_close[code] == true
end

---@param code integer
---@return boolean
local function is_cjk_right_boundary(code)
   return is_cjk(code) or cjk_open[code] == true
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
      or ascii_prefix[code] == true
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
         or ascii_open[right] == true
         or (ascii_prefix[right] == true and has_ascii_core_after(chars, idx + 1))
   end

   if is_cjk_right_boundary(right) then
      return is_ascii_core(left)
         or ascii_close[left] == true
         or (is_ascii_token_char(left) and has_ascii_core_before(chars, idx))
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

---@param text string
---@return integer?
local function first_char_code(text)
   local chars = utf8_chars(text)
   return chars[1] and chars[1].code or nil
end

---@param text string
---@return integer?
local function last_char_code(text)
   local chars = utf8_chars(text)
   return chars[#chars] and chars[#chars].code or nil
end

---@param chunks table[]
---@return string
local function join_markdown_chunks(chunks)
   local out = {}
   local last_kind = nil

   for _, chunk in ipairs(chunks) do
      if chunk.text ~= "" then
         local prev = out[#out]
         if prev then
            local left = last_char_code(prev)
            local right = first_char_code(chunk.text)

            if left and right and not is_space(left) and not is_space(right) then
               if chunk.kind == "raw" and is_cjk_left_boundary(left) then
                  out[#out + 1] = " "
               elseif last_kind == "raw" and is_cjk_right_boundary(right) then
                  out[#out + 1] = " "
               end
            end
         end

         out[#out + 1] = chunk.text
         last_kind = chunk.kind
      end
   end

   return table.concat(out)
end

---@param chunks table[]
---@param text string
local function push_text_chunks(chunks, text)
   local pos = 1

   while true do
      local url_start, url_end = text:find("%a[%w%+%.%-]*://%S+", pos)
      if not url_start then
         chunks[#chunks + 1] = { kind = "text", text = M.spacing_text(text:sub(pos)) }
         break
      end

      chunks[#chunks + 1] = { kind = "text", text = M.spacing_text(text:sub(pos, url_start - 1)) }
      chunks[#chunks + 1] = { kind = "raw", text = text:sub(url_start, url_end) }
      pos = url_end + 1
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
      elseif in_fence then
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
