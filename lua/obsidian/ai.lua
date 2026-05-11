-- Minimal AI assistant scaffold.
-- Build context, fill prompt template, dispatch via _opencode.
-- Caller decides what to do with response (insert, replace, pick).

local M = {}

M.context = {}

---@return string text, integer start_row, integer end_row
function M.context.paragraph(bufnr)
   bufnr = bufnr or 0
   local row = vim.api.nvim_win_get_cursor(0)[1]
   local last = vim.api.nvim_buf_line_count(bufnr)
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

   local s, e = row, row
   while s > 1 and lines[s - 1] ~= "" do
      s = s - 1
   end
   while e < last and lines[e + 1] ~= "" do
      e = e + 1
   end
   return table.concat(vim.list_slice(lines, s, e), "\n"), s, e
end

---@return string
function M.context.buffer(bufnr)
   return table.concat(vim.api.nvim_buf_get_lines(bufnr or 0, 0, -1, false), "\n")
end

---@return string|nil
function M.context.selection()
   local v = require("obsidian.api").get_visual_selection()
   return v and v.lines or nil
end

---@return string name, integer row, integer col
function M.context.position()
   local row, col = table.unpack(vim.api.nvim_win_get_cursor(0))
   return vim.api.nvim_buf_get_name(0), row, col
end

---@param opts { prompt: string, flags?: table, dir?: string, cwd?: string }
---@param callback fun(stdout: string)
function M.run(opts, callback)
   local flags = vim.tbl_extend("force", {}, opts.flags or {})
   if opts.dir then
      flags.dir = opts.dir
   end
   require("_opencode")(opts.prompt, flags, callback)
end

-- Parse agent output into list of items.
-- Strategy: find fenced JSON array; fallback to non-empty lines stripped of list markers.
---@param text string
---@return string[]
function M.parse_list(text)
   local json = text:match("```json%s*(.-)```") or text:match("```%s*(.-)```") or text:match("%[.-%]")
   if json then
      local ok, decoded = pcall(vim.json.decode, json)
      if ok and type(decoded) == "table" then
         return decoded
      end
   end
   local items = {}
   for line in text:gmatch("[^\n]+") do
      local item = line:gsub("^%s*[-*%d.]+%s*", ""):gsub("^%s+", ""):gsub("%s+$", "")
      if item ~= "" then
         items[#items + 1] = item
      end
   end
   return items
end

return M
