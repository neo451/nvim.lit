local obsidian = require("obsidian")

local function normalize_words(words)
   if type(words) ~= "table" then
      return {}
   end

   local out = {}
   local seen = {}
   for _, word in pairs(words) do
      if type(word) == "string" then
         local normalized = vim.trim(word)
         if normalized ~= "" and not seen[normalized] then
            seen[normalized] = true
            table.insert(out, normalized)
         end
      end
   end

   return out
end

local function ensure_tmp_spellfile(bufnr)
   local tmp_spellfile = vim.b[bufnr].obsidian_tmp_spellfile
   if type(tmp_spellfile) == "string" and tmp_spellfile ~= "" then
      return tmp_spellfile
   end

   tmp_spellfile = vim.fn.tempname() .. "." .. vim.o.encoding .. ".add"
   vim.b[bufnr].obsidian_tmp_spellfile = tmp_spellfile
   return tmp_spellfile
end

local function apply_frontmatter_words(words, bufnr)
   local normalized_words = normalize_words(words)
   if vim.tbl_isempty(normalized_words) then
      return
   end

   local tmp_spellfile = ensure_tmp_spellfile(bufnr)
   vim.fn.writefile(normalized_words, tmp_spellfile)
   vim.cmd("silent mkspell! " .. vim.fn.fnameescape(tmp_spellfile))

   local spellfiles = vim.opt_local.spellfile:get()
   if not vim.tbl_contains(spellfiles, tmp_spellfile) then
      vim.opt_local.spellfile:append(tmp_spellfile)
   end
end

--- get spell bad in the region TODO: other
local function get_spell()
   local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
   local results = {}
   for _, line in ipairs(lines) do
      while true do
         local word, type = unpack(vim.fn.spellbadword(line))
         if word == "" or type ~= "bad" then
            break
         end
         local _, ed = line:find(vim.pesc(word))
         assert(ed, "should find end in line")
         line = line:sub(ed + 1)
         results[#results + 1] = word
      end
   end

   return results
end

local function update(word)
   local note = obsidian.api.current_note()
   if not note then
      return
   end
   local words = note.metadata and note.metadata.words or {}
   table.insert(words, word)
   note:add_field("words", words)
   local buf = vim.api.nvim_get_current_buf()
   note:update_frontmatter(buf)
   apply_frontmatter_words(words, buf)
end

-- TODO: one function

vim.keymap.set("n", "zG", function()
   local word = vim.fn.expand("<cword>")
   if word == "" then
      return
   end
   update(word)
end)

vim.keymap.set("x", "zG", function()
   local words = get_spell()

   local esc = vim.api.nvim_replace_termcodes("<esc>", true, false, true)
   vim.api.nvim_feedkeys(esc, vim.fn.mode(), false)

   for _, word in ipairs(words) do
      update(word)
   end
end)

vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local note = obsidian.api.current_note()
      if not note then
         return
      end
      local metadata = note.metadata

      if not metadata then
         return
      end

      if vim.tbl_isempty(metadata) then
         return
      end

      apply_frontmatter_words(metadata.words, bufnr)

      for k, v in pairs(metadata) do
         if vim.startswith(k, ".") then
            vim.opt_local[k:sub(2)] = v
         end
      end
   end,
})
