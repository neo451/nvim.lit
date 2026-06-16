local lsp = vim.lsp
local ms = vim.lsp.protocol.Methods
local util = vim.lsp.util

local COMPLETION = ms.textDocument_completion
local ENUM_MEMBER = lsp.protocol.CompletionItemKind.EnumMember
local TIMEOUT_MS = 500

---@param bufnr integer
---@return vim.lsp.Client[]
local function completion_clients(bufnr)
   return vim.iter(lsp.get_clients({ bufnr = bufnr, method = COMPLETION }))
      :filter(function(client)
         return client.initialized and not client:is_stopped()
      end)
      :totable()
end

---@param result lsp.CompletionList|lsp.CompletionItem[]?
---@return lsp.CompletionItem[]
local function result_items(result)
   if type(result) ~= "table" then
      return {}
   end

   return result.items or result
end

---@return lsp.CompletionItem[]
local function get_lsp_items()
   local bufnr = vim.api.nvim_get_current_buf()
   local clients = completion_clients(bufnr)

   if vim.tbl_isempty(clients) then
      return {}
   end

   local seen = {}
   local items = {}

   for _, client in ipairs(clients) do
      local params = util.make_position_params(0, client.offset_encoding or "utf-16")
      params.context = { triggerKind = lsp.protocol.CompletionTriggerKind.Invoked }

      local ok, response = pcall(client.request_sync, client, COMPLETION, params, TIMEOUT_MS, bufnr)
      local result = ok and response and not response.err and response.result

      for _, item in ipairs(result_items(result)) do
         if item.kind == ENUM_MEMBER and item.label and item.label ~= "" and not seen[item.label] then
            table.insert(items, item)
            seen[item.label] = true
         end
      end
   end

   return items
end

---@param items lsp.CompletionItem[]
---@param line string
---@param cursor integer 1-based byte column
---@return { index: integer, from: integer, to: integer, text: string }?
local function find_item_on_cursor(items, line, cursor)
   local best

   for index, item in ipairs(items) do
      local text = item.label
      local from = math.max(cursor - #text + 1, 1)
      local found = line:find(text, from, true)

      if found and found <= cursor then
         local candidate = {
            index = index,
            from = found,
            to = found + #text - 1,
            text = text,
         }

         if
            not best
            or #candidate.text > #best.text
            or (#candidate.text == #best.text and candidate.from < best.from)
         then
            best = candidate
         end
      end
   end

   return best
end

---@param addend integer
---@return boolean handled
local function lsp_dial(addend)
   local items = get_lsp_items()

   if vim.tbl_isempty(items) then
      return false
   end

   local pos = vim.api.nvim_win_get_cursor(0)
   local row = pos[1]
   local col = pos[2]
   local line = vim.api.nvim_get_current_line()
   local match = find_item_on_cursor(items, line, col + 1)

   if not match then
      return false
   end

   local next_index = (match.index + addend - 1) % #items + 1
   local next_text = items[next_index].label

   vim.api.nvim_buf_set_text(0, row - 1, match.from - 1, row - 1, match.to, { next_text })

   local offset = col - (match.from - 1)
   local next_col = (match.from - 1) + math.min(offset, math.max(#next_text - 1, 0))
   vim.api.nvim_win_set_cursor(0, { row, next_col })

   return true
end

---@param keys string
local function feed_builtin(keys)
   local count = vim.v.count > 0 and tostring(vim.v.count) or ""
   vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(count .. keys, true, false, true), "n", false)
end

local function cword_is_number()
   local cword = vim.fn.expand("<cword>")
   return cword ~= "" and tonumber(cword) ~= nil
end

---@param addend integer
---@param fallback string
local function dial_or_fallback(addend, fallback)
   if not cword_is_number() and lsp_dial(addend * vim.v.count1) then
      return
   end

   feed_builtin(fallback)
end

vim.keymap.set("n", "<Plug>(LspDialInc)", function()
   lsp_dial(vim.v.count1)
end)

vim.keymap.set("n", "<Plug>(LspDialDec)", function()
   lsp_dial(-vim.v.count1)
end)

vim.keymap.set("n", "<C-a>", function()
   dial_or_fallback(1, "<C-a>")
end, { desc = "Increment number or LSP enum" })

vim.keymap.set("n", "<C-x>", function()
   dial_or_fallback(-1, "<C-x>")
end, { desc = "Decrement number or LSP enum" })
