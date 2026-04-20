local cache = {}

local function resovle_image(path, src)
   local api = require("obsidian.api")
   local util = require("obsidian.util")
   local is_uri, scheme = util.is_uri(src)
   if not api.path_is_note(path) then
      return
   end

   if is_uri and scheme == "https" then
      if cache[src] then
         return cache[src]
      end
      local tmp = vim.fn.tempname() .. ".jpg" -- TODO: get suffix
      local cmd = { "curl", "-L", "-o", tmp, src }
      local result = vim.system(cmd):wait()
      if result.code == 0 then
         cache[src] = tmp
         print(tmp)
         return tmp
      else
         vim.notify("Failed to download image: " .. result.stderr, vim.log.levels.ERROR)
         return nil
      end
   else
      return api.resolve_attachment_path(src)
   end
end

require("snacks").setup({
   gitbrowse = { enabled = true },
   scroll = { enabled = true },
   image = {
      enabled = vim.fn.executable("convert") == 1,
      resolve = resovle_image,
      -- wo = { winhighlight = "FloatBorder:WhichKeyBorder" },
      doc = {
         inline = true,
         max_width = 45,
         max_height = 20,
      },
   },
   input = { enabled = true },
   picker = { enabled = true },
   statuscolumn = { enabled = true },
   styles = {
      notification = {
         wo = { wrap = true },
      },
   },
   notifier = {
      enabled = true,
      timeout = 3000,
   },
})
