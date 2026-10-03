local M = {}

local registered = {}
local generated = {}

local finals = {
   a = "a",
   ai = "d",
   an = "j",
   ang = "h",
   ao = "c",
   e = "e",
   ei = "w",
   en = "f",
   eng = "g",
   er = "r",
   o = "o",
   ou = "z",
   ong = "s",
   i = "i",
   ia = "x",
   ian = "m",
   iang = "l",
   iao = "n",
   ie = "p",
   ["in"] = "b",
   ing = "k",
   iong = "s",
   iu = "q",
   u = "u",
   ua = "x",
   uai = "k",
   uan = "r",
   uang = "l",
   ue = "t",
   ui = "v",
   un = "y",
   uo = "o",
   v = "v",
   ve = "t",
   van = "r",
   vn = "y",
}

local function unique(values)
   local result = {}
   local seen = {}
   for _, value in ipairs(values) do
      if value ~= "" and not seen[value] then
         seen[value] = true
         result[#result + 1] = value
      end
   end
   return #result == 1 and result[1] or result
end

local function as_list(value)
   if type(value) == "table" then
      return value
   end
   return { value }
end

local function xiaohe(spelling)
   spelling = spelling:lower():gsub("%d", ""):gsub("ü", "v")

   -- In standard Hanyu Pinyin, ju/qu/xu/yu use u for the ü sound.
   local initial, rest
   for _, candidate in ipairs({ "zh", "ch", "sh" }) do
      if spelling:sub(1, #candidate) == candidate then
         initial = candidate
         rest = spelling:sub(#candidate + 1)
         break
      end
   end
   if not initial then
      initial, rest = spelling:match("^([bpmfdtnlgkhjqxrzcsyw])(.*)$")
   end
   if not initial then
      -- Zero-initial syllables are the only place where the first vowel
      -- doubles as an initial (a -> aa, o -> oo, e -> ee).
      if spelling == "a" or spelling == "o" or spelling == "e" then
         return spelling .. spelling
      end
      if spelling == "ai" or spelling == "ei" or spelling == "ao" or spelling == "ou" then
         return spelling
      end
      initial, rest = spelling:sub(1, 1), spelling:sub(2)
   end

   if rest == "u" and initial:match("^[jqxy]$") then
      rest = "v"
   end
   rest = finals[rest] or rest

   local initial_key = ({ zh = "v", ch = "i", sh = "u" })[initial] or initial
   return initial_key .. rest
end

local function full_table()
   return require("qol.pinyin_search.data")
end

local function xiaohe_table()
   if generated.xiaohe then
      return generated.xiaohe
   end

   local result = {}
   for character, readings in pairs(full_table()) do
      local converted = {}
      for _, reading in ipairs(as_list(readings)) do
         converted[#converted + 1] = xiaohe(reading)
      end
      result[character] = unique(converted)
   end
   generated.xiaohe = result
   return result
end

function M.register(name, table_or_function)
   assert(type(name) == "string" and name ~= "", "a spelling table needs a name")
   assert(
      type(table_or_function) == "table" or type(table_or_function) == "function",
      "a spelling table must be a table or function"
   )
   registered[name] = table_or_function
   generated[name] = nil
end

function M.resolve(name)
   if name == "full" or name == "pinyin" then
      return full_table()
   elseif name == "xiaohe" or name == "flypy" or name == "小鹤双拼" then
      return xiaohe_table()
   end

   local table_or_function = registered[name]
   if not table_or_function then
      error("unknown pinyin spelling table: " .. tostring(name))
   end
   if type(table_or_function) == "function" then
      if not generated[name] then
         generated[name] = table_or_function()
      end
      return generated[name]
   end
   return table_or_function
end

function M.setup(opts)
   opts = opts or {}
   for name, table_or_function in pairs(opts.tables or {}) do
      M.register(name, table_or_function)
   end
end

function M.to_xiaohe(spelling)
   return xiaohe(spelling)
end

return M
