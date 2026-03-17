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

vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local note = obsidian.api.current_note()
      if not note then
         return
      end
      if vim.tbl_isempty(note.metadata) then
         return
      end

      apply_frontmatter_words(note.metadata.words, bufnr)

      local options = note.metadata.nvim
      if not options or vim.tbl_isempty(options) then
         return
      end
      for k, v in pairs(note.metadata.nvim) do
         vim.o[k] = v
      end
   end,
})
