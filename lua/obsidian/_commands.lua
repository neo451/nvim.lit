---@module 'obsidian'
---@class ObsidianSubCommands
---@field refresh_tags obsidian.CommandConfig
---@field add_tags obsidian.CommandConfig

vim.api.nvim_create_autocmd("CmdlineChanged", {
   callback = function()
      local cmdline = vim.fn.getcmdline()
      if vim.fn.getcmdtype() ~= ":" then
         return
      end
      if not cmdline:match("^Obsidian[A-Za-z0-9]*$") then
         return
      end
      vim.fn.wildtrigger()
   end,
})

--@type ObsidianSubCommands
local obsidian_subcommands = {
   refresh_tags = {
      func = function()
         local obsidian_ok, obsidian = pcall(require, "obsidian")
         if not obsidian_ok then
            error("Tried to run 'Obsidian refresh_tags' while obsidian wasn't loaded")
         end

         local tag_locations = obsidian.search.find_tags("")
         local tags = {}
         for _, tag_loc in ipairs(tag_locations) do
            local tag = tag_loc.tag
            if not tags[tag] then
               tags[tag] = true
            end
         end

         local keys = vim.tbl_keys(tags)
         table.sort(keys)
         vim.g.tagstore = keys
      end,
      nargs = 0,
      desc = "Refreshes the list of tags to be used by :ObsidianAddTags",
   },
   add_tags = {
      func = function(opts)
         local obsidian_ok, obsidian = pcall(require, "obsidian")
         if not obsidian_ok then
            error("Tried to run 'Obsidian add_tags' while obsidian wasn't loaded")
         end

         local current_note = obsidian.api.current_note()
         if current_note == nil then
            error("Couldn't fetch current note")
         end

         for _, value in ipairs(opts.fargs) do
            current_note:add_tag(value)
         end
         current_note:update_frontmatter()
      end,
      nargs = "+",
      complete = function(arg_lead, cmd_line, cursor_pos)
         local result = {}

         if not vim.g.tagstore then
            vim.notify("tagstore is empty, no completion possible")
            return result
         end

         if arg_lead == "" then
            return {}
         end

         -- use vim.fn.matchfuzzy to find matches in the tagstore
         result = vim.fn.matchfuzzy(vim.g.tagstore, arg_lead, { limit = 10 })

         -- sorting the table for better readability
         table.sort(result)

         return result
      end,
      desc = "Adds tags separated by whitespace to the currently opened note",
   },
}

return obsidian_subcommands
