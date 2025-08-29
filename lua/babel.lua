local ts = vim.treesitter
local table, loadstring = table, loadstring
local api = vim.api
local ns_id = api.nvim_create_namespace("cb_run")
local cb_id = 0

local M = {}

local inspect_node = function(node)
   if node then
      local buf = vim.api.nvim_get_current_buf()
      vim.print(node:type(), ts.get_node_text(node, buf))
   else
      vim.notify_once("found no node", 3)
   end
end

---@param node TSNode?
---@return TSNode?
local function find_code_block(node)
   while node and node:type() ~= "fenced_code_block" do
      if node:parent() ~= nil then
         node = assert(node:parent())
      else
         return nil
      end
   end
   return node
end

---@return string?
local get_code_block = function()
   local buf = vim.api.nvim_get_current_buf()
   local node = find_code_block(ts.get_node())

   -- TODO: node pos
   if node then
      return ts.get_node_text(node, buf)
   end
end

---@param code string
---@return string code
---@return string lang
function M.parse_block(code)
   local lines = vim.split(code, "\n")
   local lang = table.remove(lines, 1):sub(4)
   table.remove(lines, #lines)
   return table.concat(lines, "\n"), lang
end

-- TODO: default display positions:
-- 1. after last line
-- 2. below code block
-- TODO: support more lang, with vim.system
-- TODO: virtual line like diagnositics

---@param bnr integer
---@param line_num integer
---@param col_num integer
---@param text string
---@param id integer
local function display_result(bnr, line_num, col_num, text, id)
   local opts = {
      id = id,
      virt_text = { { text, "IncSearch" } },
      virt_text_pos = "eol",
   }
   local mark_id = api.nvim_buf_set_extmark(bnr, ns_id, line_num, col_num, opts)
   print(mark_id)
end

local runners = {
   lua = function(code)
      local f = loadstring(code, ("MyRunCodeBlock[%d]"):format(cb_id))
      local ret

      assert(f)
      setfenv(f, {
         print = function(v)
            ret = v
         end,
      })

      local v = f()

      if not code:find("print") then
         ret = v
      end

      return ret
   end,

   nix = function(code)
      local obj = vim.system({
         "nix",
         "eval",
         "--expr",
         code,
      }):wait()
      return vim.trim(obj.stdout)
   end,
}

--- TODO: more runners
--- TODO: run based on lang
local function run()
   local code_block = get_code_block()
   if not code_block then
      vim.notify("not on a code block")
      return
   end
   cb_id = cb_id + 1
   local code, lang = M.parse_block(code_block)
   local buf = vim.api.nvim_get_current_buf()
   local row = vim.api.nvim_win_get_cursor(0)[1] - 1

   local result = runners[lang](code)

   display_result(buf, row, 7, result, cb_id)
end

vim.keymap.set("n", "<Plug>MyRun", run)

function M.enable(enable)
   if enable then
      vim.keymap.set("n", "<S-CR>", "<Plug>MyRun")
   end
end

return M
