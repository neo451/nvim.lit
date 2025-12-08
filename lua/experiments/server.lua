local Router = require("experiments.router")

local router = Router.new()

local M = {}

local state = {
   rendered_html = "<bold>hi</bold>",
   -- Track buffers being previewed
   active_buffers = {},
   -- Debounce timer for updates
   update_timer = nil,
}

-- Function to convert markdown to HTML
local function convert_markdown_to_html(lines)
   vim.system({
      "pandoc",
      "-f",
      "markdown",
      "-t",
      "html",
   }, {
      stdin = table.concat(lines, "\n"),
   }, function(out)
      if out.code ~= 0 then
         vim.notify("Failed to convert markdown: " .. out.stderr)
         return
      end
      state.rendered_html = out.stdout
   end)
end

-- Update HTML content from current buffer
local function update_preview(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()

   if not state.active_buffers[bufnr] then
      return
   end

   -- Cancel previous timer if it exists
   if state.update_timer then
      state.update_timer:close()
      state.update_timer = nil
   end

   -- Debounce updates (150ms delay)
   state.update_timer = vim.defer_fn(function()
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      convert_markdown_to_html(lines)
   end, 150)
end

M.open = function(port)
   -- Setup router endpoints
   router:get("/", function(_, _)
      -- Return HTML with auto-refresh JavaScript
      local html = [[
        <!DOCTYPE html>
        <html>
        <head>
            <title>Markdown Preview</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
                       margin: 20px; padding: 20px; background: #f5f5f5; }
                .content { background: white; padding: 30px; border-radius: 8px; 
                          box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
            </style>
            <script>
                // Auto-refresh every second
                function refreshContent() {
                    fetch('/content')
                        .then(response => response.text())
                        .then(html => {
                            document.querySelector('.content').innerHTML = html;
                        })
                        .catch(err => console.error('Error:', err));
                }
                
                // Refresh immediately and then every second
                refreshContent();
                setInterval(refreshContent, 1000);
            </script>
        </head>
        <body>
            <div class="content">Loading...</div>
        </body>
        </html>
        ]]
      return html
   end)

   router:get("/content", function(_, _)
      return state.rendered_html
   end)

   -- Setup autocmd for markdown buffers
   local group = vim.api.nvim_create_augroup("MarkdownPreview", { clear = true })

   -- When entering a markdown buffer, start tracking it
   vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      group = group,
      callback = function(ev)
         local bufnr = ev.buf

         -- Mark this buffer as active
         state.active_buffers[bufnr] = true

         -- Convert initial content
         local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
         convert_markdown_to_html(lines)

         -- Setup buffer-local autocmds for changes
         local buf_group = vim.api.nvim_create_augroup("MarkdownPreviewBuffer" .. bufnr, { clear = true })

         -- Update on text changes (with TextChangedI for insert mode and TextChanged for normal mode)
         vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
            buffer = bufnr,
            group = buf_group,
            callback = function()
               update_preview(bufnr)
            end,
         })

         -- Update when buffer is written
         vim.api.nvim_create_autocmd("BufWritePost", {
            buffer = bufnr,
            group = buf_group,
            callback = function()
               update_preview(bufnr)
            end,
         })

         -- Clean up when buffer is closed
         vim.api.nvim_create_autocmd("BufWipeout", {
            buffer = bufnr,
            group = buf_group,
            callback = function()
               state.active_buffers[bufnr] = nil
               vim.api.nvim_del_augroup_by_id(buf_group)
            end,
         })
      end,
   })

   -- Also handle existing markdown buffers when plugin loads
   for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[bufnr].ft == "markdown" then
         state.active_buffers[bufnr] = true
         local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
         convert_markdown_to_html(lines)
      end
   end

   router:listen(port)
   print("Markdown preview server started on port " .. port)
   print("Open http://localhost:" .. port .. " in your browser")
end

M.close = function()
   if state.update_timer then
      state.update_timer:close()
      state.update_timer = nil
   end
   -- Clean up all buffer-specific autocmd groups
   for bufnr, _ in pairs(state.active_buffers) do
      pcall(vim.api.nvim_del_augroup_by_name, "MarkdownPreviewBuffer" .. bufnr)
   end
   state.active_buffers = {}
end

return M
