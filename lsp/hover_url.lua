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
      return
   end

   vim.net.request("https://markdown.new/" .. url, {}, function(err, response)
      if err or not response then
         return
      end

      cache[url] = response.body
      callback(nil, {
         contents = response.body,
      })
   end)
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
