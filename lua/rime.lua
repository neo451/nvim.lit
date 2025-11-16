local M = {}

-- -- Check if item is acceptable, you can define rules by yourself
-- function M.rime_item_acceptable(item)
--    return not contains_unacceptable_character(item.label) or item.label:match("%d%d%d%d%-%d%d%-%d%d %d%d:%d%d:%d%d%")
-- end

local function is_rime_item(item)
   if item == nil or item.source_name ~= "LSP" then
      return false
   end
   local client = vim.lsp.get_client_by_id(item.client_id)
   return client ~= nil and client.name == "rime_ls"
end

-- Get the first n rime items' index in the completion list
function M.get_n_rime_item_index(n, items)
   if items == nil then
      items = require("blink.cmp.completion.list").items
   end
   local result = {}
   if items == nil or #items == 0 then
      return result
   end
   for i, item in ipairs(items) do
      if is_rime_item(item) then
         result[#result + 1] = i
         if #result == n then
            break
         end
      end
   end
   return result
end
function M.blink_cmp_select_wrapper(index)
   -- TODO: not in a markdown codeblock
   return function(cmp)
      if not vim.g.rime_enabled then
         return false
      end
      local rime_item_index = M.get_n_rime_item_index(1)
      if #rime_item_index ~= index then
         return false
      end
      return cmp.accept({ index = rime_item_index[1] })
   end
end

return M
