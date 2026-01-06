vim.ui.open = (function(overridden)
   return function(uri, opt)
      if vim.endswith(uri, ".png") then
         vim.cmd("edit " .. uri) -- early return to just open in neovim
         return
      elseif vim.endswith(uri, ".pdf") then
         opt = { cmd = { "zathura" } } -- override open app
      end
      return overridden(uri, opt)
   end
end)(vim.ui.open)

vim.filetype.add({
   extension = {
      base = "yaml",
   },
})

local obsidian = require("obsidian")
---@module 'obsidian'

---@return string[]
local list_tags = function()
   local tag_locations = obsidian.search.find_tags("")
   local tags = {}
   for _, tag_loc in ipairs(tag_locations) do
      local tag = tag_loc.tag
      if not tags[tag] then
         tags[tag] = true
      end
   end
   return vim.tbl_keys(tags)
end

local handlers = {
   tags = function()
      local tags = list_tags()

      local list = {}

      for _, tag in ipairs(tags) do
         list[#list + 1] = string.format("'%s'", tag)
      end

      local list_str = table.concat(list, ", ")

      local format = [[
function! ObsidianTagsComplete(A, L, P)
  return [%s]
endfunction
   ]]

      local func_str = string.format(format, list_str)
      vim.cmd(func_str)
   end,
}

local workspaces = {
   {
      name = "notes",
      path = "~/Documents/Notes/",
   },
   {
      name = "blog",
      path = "~/quarto-blog/posts/",
   },
   -- {
   --    name = "test",
   --    path = "~/Vaults/test/",
   --    overrides = {
   --       daily_notes = { enabled = false },
   --       templates = { enabled = false },
   --    },
   -- },
   -- {
   --    name = "auto",
   --    path = function()
   --       local path = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
   --       local prev = ""
   --       while path ~= "" and path ~= prev do
   --          if vim.uv.fs_stat(path .. "/.obsidian") then
   --             return path
   --          end
   --          prev, path = path, vim.fs.dirname(path)
   --       end
   --       return nil
   --    end,
   -- },
}

local VAULTS = "~/Vaults/"

local overrides = {}

-- for dir, t in vim.fs.dir(VAULTS) do
--    if t == "directory" then
--       local spec = {
--          path = vim.fs.joinpath(VAULTS, dir),
--       }
--       if overrides[dir] then
--          spec.overrides = overrides[dir]
--       end
--       workspaces[#workspaces + 1] = spec
--    end
-- end

local api = vim.api

local ns_id = api.nvim_create_namespace("due display")

---@param bnr integer
---@param line_num integer
---@param text string
---@param id integer
---@return integer
local function display_result(bnr, line_num, text, id)
   local opts = {
      id = id,
      virt_text = { { text, "DiagnosticVirtualTextHint" } },
      virt_text_pos = "eol",
   }
   local mark_id = api.nvim_buf_set_extmark(bnr, ns_id, line_num, 0, opts)
   return mark_id
end

local id_c = 1

-- TODO: through diagnostic
-- TODO: multiple link, note resolve ...
vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function(ev)
      local path = vim.api.nvim_buf_get_name(ev.buf)
      if not vim.endswith(path, "todo.md") then
         return
      end
      local ok, note = pcall(obsidian.Note.from_buffer, ev.buf)
      if not ok then
         return
      end
      for _, link_match in ipairs(note:links()) do
         local line = link_match.line - 1
         local loc = obsidian.util.parse_link(link_match.link)
         if loc then
            local notes = obsidian.search.resolve_note(loc)
            if #notes == 1 then
               local ref = notes[1]
               local due = ref.metadata.due
               if due then
                  display_result(ev.buf, line, "<- " .. due, id_c)
                  id_c = id_c + 1
               end
            else
               -- obsidian.log.info("failed to resolve note link")
            end
         end
      end
   end,
})

vim.api.nvim_create_autocmd("User", {
   pattern = "ObsidianNoteEnter",
   callback = function()
      local note = obsidian.api.current_note()
      if not note then
         return
      end
      if vim.tbl_isempty(note.metadata) then
         return
      end
      local options = note.metadata.nvim
      if not options or vim.tbl_isempty(options) then
         return
      end
      for k, v in pairs(note.metadata.nvim) do
         vim.o[k] = v
      end
   end,
})

obsidian.setup({
   bookmarks = {
      group = true,
   },

   completion = {
      min_chars = 2,
   },

   frontmatter = {
      func = function(note)
         local out = require("obsidian.builtin").frontmatter(note)
         if note.id == "albums2025" then
            local count = 0
            for _, line in ipairs(note.contents) do
               if line:match("^%d*%. ") then
                  count = count + 1
               end
            end
            out.count = count
         elseif note.id == "nvim" then
            local count = 0
            for _, line in ipairs(note.contents) do
               if line:match("#* %w*/%w*") then
                  count = count + 1
               end
            end
            out.count = count
         end
         if vim.tbl_isempty(note.aliases) then
            out.aliases = nil
         end
         return out
      end,
      enabled = function(path)
         if vim.endswith(tostring(path), ".qmd") then
            return false
         end

         if Obsidian.workspace.name == "wiki" then
            return false
         end

         return true
      end,
   },

   lsp = {
      hover = {
         note_preview_callback = function(note)
            local contents = {}
            for i = 1, 20 do
               contents[i] = note.contents[i]
            end
            return contents
         end,
      },
   },

   callbacks = {
      ---@param note obsidian.Note
      enter_note = function(note)
         if vim.b[note.bufnr].obsidian_help then
            vim.bo[note.bufnr].readonly = false
         end

         vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { buffer = true })
         vim.keymap.set("n", "<leader>p", "<cmd>Obsidian paste<cr>", { buffer = true })

         pcall(function()
            vim.keymap.set("v", "<leader>nd", function()
               require("nldates").parse({
                  callback = function(datestring)
                     return "[[" .. datestring .. "]]"
                  end,
               })
            end)
         end)

         if vim.endswith(tostring(note.path), "todo.md") then
            vim.keymap.del("n", "<CR>", { buffer = true })
            vim.keymap.set("n", "<CR>", "<cmd>Checkmate toggle<cr>", { buffer = true })
         end

         vim.keymap.set("n", "<leader>;", obsidian.api.add_property, { buffer = true })

         vim.keymap.set("n", "<leader>cb", obsidian.api.set_checkbox, { buffer = true })
         -- vim.keymap.set("x", "<cr>", require("obsidian.api").toggle_checkbox)

         vim.keymap.set({ "n", "x" }, "<leader>cc", obsidian.api.toggle_checkbox, { buffer = true })
         -- vim.keymap.set("x", "<cr>", function()
         --    return "<cmd>Obsidian toggle_checkbox<cr>"
         -- end, { expr = true })
      end,
   },
   legacy_commands = false,
   -- prefer_config_from_obsidian_app = true,

   link = {
      format = "shortest",
      -- format = "relative",
      -- style = "markdown",
      style = "wiki",
   },

   templater = {
      commands = {
         hi = "hello",
      },
   },

   statusline = {
      enabled = false,
   },

   ---@param id string
   ---@param dir obsidian.Path
   ---@return string
   note_id_func = function(id, dir)
      return id
   end,

   comment = { enabled = false },

   ui = { enable = false },

   checkbox = {
      order = { "x", " " },
      create_new = true,
   },

   open = {
      use_advanced_uri = true,
   },

   daily_notes = {
      enabled = false,
      date_format = "%Y-%m-%d",
      template = "daily.md",
      folder = "daily_notes",
   },

   picker = {
      -- enabled = false,
      -- name = false,
      -- name = "mini.pick",
      name = "snacks.pick",
      -- name = "fzf-lua",
      -- name = "telescope.nvim",
   },

   attachments = {
      func = function(uri)
         vim.ui.open(uri)
      end,
      confirm_img_paste = true,
      folder = "./attachments",
   },

   templates = {
      enabled = false,
      folder = "templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
      customizations = {
         zettel = {
            dir = "zettel",
            note_id_func = function(title)
               return "my-cool-id+" .. title
            end,
         },
         meetings = {
            note_id_func = function(title)
               return title
            end,
         },
      },
   },
   workspaces = workspaces,
})
