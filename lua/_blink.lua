local cmp = require("blink.cmp")

local function is_rime_item(item)
   return item and item.client_name == "rime_ls"
end

local last_commit

-- Blink creates an undo point, but undo may also reverse unrelated insert edits.
-- Save only the actual text changed by the last Rime acceptance.
local function accept_rime(cmp, index, suffix)
   local bufnr = vim.api.nvim_get_current_buf()
   local original_line = vim.api.nvim_get_current_line()
   local original_cursor = vim.api.nvim_win_get_cursor(0)
   return cmp.accept({
      index = index,
      callback = function()
         if bufnr ~= vim.api.nvim_get_current_buf() then
            return
         end
         local accepted_line = vim.api.nvim_get_current_line()
         local cursor = vim.api.nvim_win_get_cursor(0)
         last_commit = nil
         if cursor[1] ~= original_cursor[1] or original_line == accepted_line then
            return
         end
         local start = 1
         while start <= math.min(#original_line, #accepted_line)
            and original_line:byte(start) == accepted_line:byte(start) do
            start = start + 1
         end
         local old_end, new_end = #original_line, #accepted_line
         while old_end >= start and new_end >= start
            and original_line:byte(old_end) == accepted_line:byte(new_end) do
            old_end, new_end = old_end - 1, new_end - 1
         end
         local raw = original_line:sub(start, old_end)
         local converted = accepted_line:sub(start, new_end)
         if not raw:match("^[%a]+[%a%d']*$") or converted == "" or cursor[2] ~= new_end then
            return
         end
         last_commit = {
            bufnr = bufnr, row = cursor[1], col = start - 1,
            raw = raw, converted = converted, line = accepted_line, cursor = cursor[2],
         }
         if suffix then
            -- Keymap is an expression mapping: defer buffer edits until it returns.
            vim.schedule(function()
               local commit = last_commit
               if not commit or commit.bufnr ~= bufnr or vim.api.nvim_get_current_buf() ~= bufnr
                  or vim.api.nvim_get_current_line() ~= commit.line
                  or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), { commit.row, commit.cursor }) then
                  return
               end
               vim.api.nvim_buf_set_text(bufnr, commit.row - 1, commit.cursor, commit.row - 1, commit.cursor, { suffix })
               vim.api.nvim_win_set_cursor(0, { commit.row, commit.cursor + #suffix })
               commit.line = vim.api.nvim_get_current_line()
               commit.cursor = commit.cursor + #suffix
            end)
         end
      end,
   })
end

local function restore_rime()
   local commit = last_commit
   if not commit then
      return false
   end
   if not vim.g.rime_enabled or commit.bufnr ~= vim.api.nvim_get_current_buf() then
      last_commit = nil
      return false
   end
   local cursor = vim.api.nvim_win_get_cursor(0)
   if cursor[1] ~= commit.row or cursor[2] ~= commit.cursor or vim.api.nvim_get_current_line() ~= commit.line then
      last_commit = nil
      return false
   end
   last_commit = nil
   cmp.hide()
   -- Do not edit the buffer inside an insert-mode mapping callback.
   vim.schedule(function()
      if not vim.api.nvim_buf_is_valid(commit.bufnr) or commit.bufnr ~= vim.api.nvim_get_current_buf()
         or vim.api.nvim_get_current_line() ~= commit.line
         or not vim.deep_equal(vim.api.nvim_win_get_cursor(0), { commit.row, commit.cursor }) then
         return
      end
      vim.api.nvim_buf_set_text(commit.bufnr, commit.row - 1, commit.col, commit.row - 1,
         commit.col + #commit.converted, { commit.raw })
      vim.api.nvim_win_set_cursor(0, { commit.row, commit.cursor + #commit.raw - #commit.converted })
   end)
   return true
end

-- Leave Markdown syntax (-, *, #, brackets) and English quotes literal.
local punctuation = {
   [","] = "，", ["."] = "。", ["?"] = "？", ["!"] = "！", [":"] = "：", [";"] = "；",
   ["("] = "（", [")"] = "）", ['"'] = "＂",
}
local prose_filetypes = {
   markdown = true, plaintex = true, quarto = true, text = true,
   tex = true, typst = true, gitcommit = true,
}

local function is_han(cp)
   return (cp >= 0x3400 and cp <= 0x9fff) or (cp >= 0x20000 and cp <= 0x3134f)
end

local function after_han()
   local col = vim.api.nvim_win_get_cursor(0)[2]
   local before = vim.api.nvim_get_current_line():sub(1, col)
   return before ~= "" and is_han(vim.fn.strgetchar(before, vim.fn.strchars(before) - 1))
end

-- Reject punctuation (including full-width variants), but keep Chinese words.
local function filter_rime_items(ctx, items)
   local keyword = ctx.get_keyword()
   local filtered = {}
   for _, item in ipairs(items) do
      if not is_rime_item(item) then
         filtered[#filtered + 1] = item
      elseif keyword:match("%a") then
         local text = item.textEdit and item.textEdit.newText or item.insertText
         if not text then
            text = item.label:gsub("^%d+[%.、%s]+", "")
         end
         local is_word = text:match("[%a%d]") ~= nil
         if not is_word then
            for i = 0, vim.fn.strchars(text) - 1 do
               if is_han(vim.fn.strgetchar(text, i)) then
                  is_word = true
                  break
               end
            end
         end
         if is_word then
            filtered[#filtered + 1] = item
         end
      end
   end
   return filtered
end

-- Return completion-list indexes rather than assuming Rime is the only LSP.
-- This keeps selection stable alongside markdown, dictionary and code sources.
local function get_rime_item_indexes(count, items)
   items = items or cmp.get_items()
   local indexes = {}
   for index, item in ipairs(items or {}) do
      if is_rime_item(item) then
         indexes[#indexes + 1] = index
         if #indexes == count then
            break
         end
      end
   end
   return indexes
end

-- rime-ls processes a trailing number as a candidate selection. Once it
-- responds with the single committed candidate, accept it immediately instead
-- of requiring a second space/Enter press.
vim.api.nvim_create_autocmd("User", {
   group = vim.api.nvim_create_augroup("BlinkRimeAutoAccept", { clear = true }),
   pattern = "BlinkCmpShow",
   callback = function(event)
      if not vim.g.rime_enabled then
         return
      end
      local context = event.data and event.data.context
      local current_context = cmp.get_context()
      if not context or not current_context or current_context.id ~= context.id then
         return
      end
      local cursor_col = context.cursor[2]
      if context.line:sub(cursor_col, cursor_col):match("%d") == nil then
         return
      end
      local indexes = get_rime_item_indexes(2)
      if #indexes == 1 then
         accept_rime(cmp, indexes[1])
      end
   end,
})

local keymap = {
      preset = "default",
      -- Space selects only when Rime is the highest-ranked item. An exact
      -- English dictionary match suppresses accidental Chinese conversion but
      -- does not need accepting, so the same key inserts a literal separator.
      ["<Space>"] = {
         function(cmp)
            if not vim.g.rime_enabled then
               return false
            end
            local items = cmp.get_items()
            local top_item = items[1]
            if top_item and is_rime_item(top_item) then
               local index = cmp.get_selected_item_idx() or 1
               if not is_rime_item(items[index]) then
                  index = 1
               end
               return accept_rime(cmp, index)
            end
            if top_item then
               cmp.hide()
               return " "
            end
            return false
         end,
         "fallback",
      },
      [";"] = {
         function(cmp)
            if not vim.g.rime_enabled then
               return false
            end
            if prose_filetypes[vim.bo.filetype] and after_han() then
               return punctuation[";"]
            end
            local indexes = get_rime_item_indexes(2)
            if #indexes == 2 then
               return accept_rime(cmp, indexes[2])
            end
            return false
         end,
         "fallback",
      },
      ["'"] = {
         function(cmp)
            if not vim.g.rime_enabled then
               return false
            end
            local indexes = get_rime_item_indexes(3)
            if #indexes == 3 then
               return accept_rime(cmp, indexes[3])
            end
            return false
         end,
         "fallback",
      },
      ["<C-y>"] = {
         function(cmp)
            local items = cmp.get_items()
            local index = cmp.get_selected_item_idx() or 1
            if vim.g.rime_enabled and is_rime_item(items[index]) then
               return accept_rime(cmp, index)
            end
            return false
         end,
         "select_and_accept",
         "fallback",
      },
}

for key, wide in pairs(punctuation) do
   if key ~= ";" then
      keymap[key] = {
         function(cmp)
            if not vim.g.rime_enabled or not prose_filetypes[vim.bo.filetype] then
               return false
            end
            local items = cmp.get_items()
            local top = items[1]
            if is_rime_item(top) and not after_han() then
               local index = cmp.get_selected_item_idx() or 1
               if not is_rime_item(items[index]) then
                  index = 1
               end
               return accept_rime(cmp, index, wide)
            end
            if after_han() then
               cmp.hide()
               return wide
            end
            return false
         end,
         "fallback",
      }
   end
end

cmp.setup({
   keymap = keymap,

   completion = {
      menu = {
         draw = {
            columns = {
               { "label", "label_description", gap = 3 },
               { "kind" },
            },
         },
      },
      documentation = { auto_show = true },
   },

   cmdline = {
      enabled = false,
   },

   sources = {
      default = {
         "lsp",
         "path",
         "snippets",
         "buffer",
      },
      per_filetype = {
         gitcommit = { "snippets" },
         markdown = { "lsp", "dictionary" },
         plaintex = { "lsp", "dictionary" },
         quarto = { "lsp", "dictionary" },
         text = { "lsp", "dictionary" },
         tex = { "lsp", "dictionary" },
         typst = { "lsp", "dictionary" },
         sql = { "snippets", "dadbod", "buffer" },
      },
      providers = {
         lsp = {
            transform_items = function(ctx, items)
               -- Preserve Text items (Rime candidates) instead of using Blink's
               -- default LSP transformer, which filters them out.
               for _, item in ipairs(items) do
                  item.score_offset = item.score_offset or 0
                  if item.kind == vim.lsp.protocol.CompletionItemKind.Snippet then
                     item.score_offset = item.score_offset - 3
                  end
                  if item.client_name == "rime_ls" or item.client_name == "obsidian-ls" then
                     item.score_offset = item.score_offset + 100
                  end
               end
               return filter_rime_items(ctx, items)
            end,
         },
         dadbod = {
            name = "Dadbod",
            module = "vim_dadbod_completion.blink",
         },
         -- Use the dictionary source
         dictionary = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.dictionary",
            transform_items = function(ctx, items)
               local keyword = ctx.get_keyword():lower()
               for _, item in ipairs(items) do
                  -- Only a valid exact English word outranks Rime. Fuzzy
                  -- dictionary guesses such as `nihc` -> `nihilistic` must not.
                  if item.label:lower() == keyword then
                     item.score_offset = (item.score_offset or 0) + 120
                  end
               end
               return items
            end,
            opts = {
               dictionary_search_threshold = 3,
               score_offset = 0,
               definition_pointers = { "!", "&", "^" },
            },
         },
      },
   },
})

return { restore_rime = restore_rime, filter_rime_items = filter_rime_items }
