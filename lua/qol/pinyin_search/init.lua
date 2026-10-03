local M = {}

local tables = require("qol.pinyin_search.tables")
local matcher = require("qol.pinyin_search.matcher")

local state = {
   buffer = nil,
   query = nil,
   matches = {},
   index = nil,
   preview_buffer = nil,
   schemes = { "full", "xiaohe" },
}

local namespace = vim.api.nvim_create_namespace("qol.pinyin_search")

local function position_is_after(left, right)
   return left.line > right.line or (left.line == right.line and left.col > right.col)
end

local function current_position()
   local position = vim.api.nvim_win_get_cursor(0)
   return { line = position[1], col = position[2] }
end

local function clear_highlights(buffer)
   if buffer and vim.api.nvim_buf_is_valid(buffer) then
      vim.api.nvim_buf_clear_namespace(buffer, namespace, 0, -1)
   end
end

local function set_highlights(buffer, matches)
   for _, match in ipairs(matches) do
      vim.api.nvim_buf_set_extmark(buffer, namespace, match.line - 1, match.start_col, {
         end_col = match.end_col,
         hl_group = "IncSearch",
         priority = 150,
      })
   end
end

local function highlight(buffer, matches)
   clear_highlights(buffer)
   set_highlights(buffer, matches)
end

local function clear_display()
   clear_highlights(state.buffer)
   if state.preview_buffer ~= state.buffer then
      clear_highlights(state.preview_buffer)
   end
   state.preview_buffer = nil
end

local function jump(index)
   local match = state.matches[index]
   if not match then
      return false
   end
   state.index = index
   -- Keep this API-only: jump() is also called from search callbacks, where
   -- executing a normal command can raise E523 (text is locked).
   vim.api.nvim_win_set_cursor(0, { match.line, match.start_col })
   return true
end

local function first_index(direction)
   local position = current_position()
   if direction > 0 then
      for index, match in ipairs(state.matches) do
         if position_is_after({ line = match.line, col = match.start_col }, position) then
            return index
         end
      end
      return 1
   end

   for index = #state.matches, 1, -1 do
      local match = state.matches[index]
      if position_is_after(position, { line = match.line, col = match.start_col }) then
         return index
      end
   end
   return #state.matches
end

function M.clear_highlights()
   clear_display()
end

function M.is_active()
   return state.buffer == vim.api.nvim_get_current_buf() and #state.matches > 0
end

function M.next(direction)
   direction = direction or 1
   if not M.is_active() then
      return false
   end

   local position = current_position()
   if direction > 0 then
      for index, match in ipairs(state.matches) do
         if position_is_after({ line = match.line, col = match.start_col }, position) then
            return jump(index)
         end
      end
      return jump(1)
   end

   for index = #state.matches, 1, -1 do
      local match = state.matches[index]
      if position_is_after(position, { line = match.line, col = match.start_col }) then
         return jump(index)
      end
   end
   return jump(#state.matches)
end

local function run(query, direction, buffer)
   query = vim.trim(query or "")
   if query == "" then
      clear_display()
      state.query = nil
      state.matches = {}
      state.index = nil
      return
   end

   buffer = buffer or vim.api.nvim_get_current_buf()
   local ok, matches = pcall(matcher.find, buffer, query, state.schemes)
   if not ok then
      vim.notify(matches, vim.log.levels.ERROR)
      return
   end

   clear_display()
   state.buffer = buffer
   state.query = query
   state.matches = matches
   state.index = nil

   if #matches == 0 then
      vim.notify("Pinyin search: pattern not found: " .. query, vim.log.levels.WARN)
      return
   end

   highlight(buffer, matches)
   jump(first_index(direction or 1))
end

-- Snacks.input calls its `highlight` callback on every TextChangedI.  Native
-- vim.ui.input implementations simply ignore the extra option, so this keeps
-- live preview optional without making the search depend on Snacks.
local function preview(query, buffer)
   clear_display()
   query = vim.trim(query or "")
   if query == "" or not vim.api.nvim_buf_is_valid(buffer) then
      return {}
   end

   local ok, matches = pcall(matcher.find, buffer, query, state.schemes)
   if not ok then
      return {}
   end
   state.preview_buffer = buffer
   set_highlights(buffer, matches)
   return {}
end

function M.search(query, opts)
   if type(query) == "table" then
      opts = query
      query = nil
   end
   opts = opts or {}

   if query then
      run(query, opts.direction)
      return
   end

   local source_buffer = vim.api.nvim_get_current_buf()
   vim.ui.input({
      prompt = opts.direction == -1 and "?" or "/",
      default = state.query or "",
      highlight = function(text)
         return preview(text, source_buffer)
      end,
   }, function(input)
      if input then
         run(input, opts.direction, source_buffer)
      elseif state.matches and #state.matches > 0 and state.buffer == source_buffer then
         -- Cancelling a live preview restores the last confirmed search.
         highlight(state.buffer, state.matches)
      else
         clear_display()
      end
   end)
end

function M.setup(opts)
   opts = opts or {}
   tables.setup(opts)
   if opts.schemes then
      state.schemes = opts.schemes
   end

   if not state.setup then
      state.setup = true
      local group = vim.api.nvim_create_augroup("qol_pinyin_search", { clear = true })
      vim.api.nvim_create_autocmd("CmdlineLeave", {
         group = group,
         pattern = ":",
         callback = function()
            local command = vim.fn.getcmdline():match("^%s*(%S+)")
            if command == "noh" or command == "nohl" or command == "nohlsearch" then
               M.clear_highlights()
            end
         end,
         desc = "Clear pinyin search highlights with :nohlsearch",
      })
   end

   if vim.fn.exists(":PinyinSearch") == 0 then
      vim.api.nvim_create_user_command("PinyinSearch", function(command)
         M.search(command.args ~= "" and command.args or nil)
      end, {
         nargs = "?",
         desc = "Search Chinese text with pinyin or a custom spelling table",
      })
   end
end

return M
