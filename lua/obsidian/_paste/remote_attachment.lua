local util = require("obsidian.util")
local api = require("obsidian.api")

local function fetch_remote_file(url, basename)
   local vault_attachment_path = api.resolve_attachment_path(basename)
   local out = vim.system({ "curl", url, "-o", vault_attachment_path }):wait(50000)
   if out.code ~= 0 then
      vim.notify("failed to copy attachment to vault " .. out.stderr)
      return
   end
end

local function handle_remote_resource_as_attachment(url)
   local basename = vim.fs.basename(url)

   local choice = api.confirm("How to handle remote file", "&Attach\n&Embed\n&Link")
   local link

   if choice == "Link" then
      link = ("![%s](%s)"):format(basename, url)
   elseif choice == "Attach" then
      fetch_remote_file(url, basename)
      link = ("[%s](%s)"):format(basename, util.urlencode(basename, { keep_path_sep = true }))
   elseif choice == "Embed" then
      fetch_remote_file(url, basename)
      link = ("![%s](%s)"):format(basename, util.urlencode(basename, { keep_path_sep = true }))
   end

   return link
end

return handle_remote_resource_as_attachment
