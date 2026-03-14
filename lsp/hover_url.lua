local ms = vim.lsp.protocol.Methods

local cap = {
   capabilities = {
      hoverProvider = true,
   },
   serverInfo = {
      name = "hover_url",
      version = "1.0.0",
   },
}

local cache = {}

local function fetch_markdown(url, callback)
   if cache[url] then
      callback(nil, {
         contents = cache[url],
      })
   end
   vim.system(
      { "curl", "-s", "https://markdown.new/" .. url },
      {},
      vim.schedule_wrap(function(out)
         if out.code ~= 0 then
            return
         end
         cache[url] = out.stdout
         callback(nil, {
            contents = out.stdout,
         })
      end)
   )
end

return {
   cmd = function()
      return {
         request = function(method, params, handler, _)
            if method == ms.textDocument_hover then
               local urls = vim.ui._get_urls()
               if not vim.tbl_isempty(urls) then
                  local url = urls[1]
                  fetch_markdown(url, handler)
               end
            elseif method == ms.initialize then
               handler(nil, cap)
            end
         end,
         notify = function(method, params, handler, _) end,
         is_closing = function() end,
         terminate = function() end,
      }
   end,
   filetypes = { "markdown" },
}
