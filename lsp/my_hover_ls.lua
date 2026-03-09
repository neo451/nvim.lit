local ms = vim.lsp.protocol.Methods

local capabilities = {
   capabilities = {
      hoverProvider = true,
   },
   serverInfo = {
      name = "my-hover-ls",
      version = "0.0.1",
   },
}

local function cursor_is_url()
   local urls = vim.ui._get_urls()

   if not vim.tbl_isempty(urls) and vim.startswith(urls[1], "https://") then
      return true, urls[1]
   end
   return false, nil
end

local cache = {}

-- TODO: make async once the vim.spinner is available, and display a spinner while fetching the content
local function fetch_markdown(url)
   if cache[url] then
      return cache[url]
   end
   local out = vim.system({ "curl", "-s", "https://markdown.new/" .. url }):wait()
   if out.code == 0 then
      cache[url] = out.stdout
      -- NOTE: pipe through a markdown formatter here?
      return out.stdout
   else
      return "Failed to fetch markdown content."
   end
end

return {
   cmd = function()
      return {
         request = function(method, _, handler, _)
            if method == ms.textDocument_hover then
               local is_url, url = cursor_is_url()
               print(url)
               -- other stuff you want to hover
               if is_url then
                  handler(nil, {
                     contents = {
                        kind = "markdown",
                        value = fetch_markdown(url),
                     },
                  })
               end
            elseif method == ms.initialize then
               handler(nil, capabilities)
            end
         end,
         notify = function() end,
         is_closing = function() end,
         terminate = function() end,
      }
   end,
   filetypes = { "markdown" },
}
