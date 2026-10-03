local function is_rime_item(item)
   return item.client_name == "rime_ls"
end

local pending_space
local double_space_timeout_ms = 500

-- A quick second space after a Rime commit restores the raw spelling and
-- inserts a literal space, providing an escape hatch for names and unknown
-- English words.
local function consume_pending_space(cmp)
   if not pending_space then
      return false
   end

   local pending = pending_space
   pending_space = nil
   if pending.bufnr ~= vim.api.nvim_get_current_buf() or not vim.api.nvim_buf_is_valid(pending.bufnr) then
      return false
   end
   if pending.expires_at and vim.uv.now() > pending.expires_at then
      return false
   end

   local cursor = vim.api.nvim_win_get_cursor(0)
   if
      vim.api.nvim_get_current_line() ~= pending.accepted_line
      or cursor[1] ~= pending.accepted_cursor[1]
      or cursor[2] ~= pending.accepted_cursor[2]
   then
      return false
   end

   cmp.hide()
   if pending.original_line then
      -- Text may not be changed directly from an expression mapping. Restore
      -- the raw spelling and add the separator on the next event-loop turn.
      vim.schedule(function()
         if pending.bufnr ~= vim.api.nvim_get_current_buf() or not vim.api.nvim_buf_is_valid(pending.bufnr) then
            return
         end
         local row, col = pending.original_cursor[1], pending.original_cursor[2]
         local line = pending.original_line:sub(1, col) .. " " .. pending.original_line:sub(col + 1)
         vim.api.nvim_buf_set_lines(pending.bufnr, row - 1, row, false, { line })
         vim.api.nvim_win_set_cursor(0, { row, col + 1 })
      end)
      return true
   end
   return " "
end

local function accept_rime_on_space(cmp, index)
   local bufnr = vim.api.nvim_get_current_buf()
   local original_line = vim.api.nvim_get_current_line()
   local original_cursor = vim.api.nvim_win_get_cursor(0)
   return cmp.accept({
      index = index,
      callback = function()
         pending_space = {
            bufnr = bufnr,
            accepted_line = vim.api.nvim_get_current_line(),
            accepted_cursor = vim.api.nvim_win_get_cursor(0),
            original_line = original_line,
            original_cursor = original_cursor,
            expires_at = vim.uv.now() + double_space_timeout_ms,
         }
      end,
   })
end

-- Return completion-list indexes rather than assuming Rime is the only LSP.
-- This keeps selection stable alongside markdown, dictionary and code sources.
local function get_rime_item_indexes(count, items)
   items = items or require("blink.cmp.completion.list").items
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

require("blink.cmp").setup({
   keymap = {
      preset = "default",
      -- Space selects only when Rime is the highest-ranked item. An exact
      -- English dictionary match suppresses accidental Chinese conversion but
      -- does not need accepting, so the same key inserts a literal separator.
      ["<Space>"] = {
         function(cmp)
            if not vim.g.rime_enabled then
               return false
            end
            local escaped = consume_pending_space(cmp)
            if escaped then
               return escaped
            end

            local list = require("blink.cmp.completion.list")
            local top_item = list.items[1]
            if top_item and is_rime_item(top_item) then
               local index = list.selected_item_idx or 1
               if not is_rime_item(list.items[index]) then
                  index = 1
               end
               return accept_rime_on_space(cmp, index)
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
            local indexes = get_rime_item_indexes(2)
            if #indexes == 2 then
               return cmp.accept({ index = indexes[2] })
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
               return cmp.accept({ index = indexes[3] })
            end
            return false
         end,
         "fallback",
      },
   },

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
         gitcommit = { "lsp", "dictionary" },
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
            transform_items = function(_, items)
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
               return items
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

-- rime-ls processes a trailing number as a candidate selection. Once it
-- responds with the single committed candidate, accept it immediately instead
-- of requiring a second space/Enter press.
require("blink.cmp.completion.list").show_emitter:on(function(event)
   if not vim.g.rime_enabled then
      return
   end
   local cursor_col = event.context.cursor[2]
   if event.context.line:sub(cursor_col, cursor_col):match("%d") == nil then
      return
   end
   local indexes = get_rime_item_indexes(2, event.items)
   if #indexes == 1 then
      require("blink.cmp").accept({ index = indexes[1], force = true })
   end
end)
