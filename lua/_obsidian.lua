local obsidian = require("obsidian")

vim.api.nvim_set_hl(0, "ObsidianSyncSynced", { fg = "#18e379", bold = true })
vim.api.nvim_set_hl(0, "ObsidianSyncSyncing", { fg = "#e5c07b" })
vim.api.nvim_set_hl(0, "ObsidianSyncPaused", { fg = "#61afef" })

pcall(function()
   require("obsidian.lsp.watchfiles").register_handler(function(events, raw_changes)
      for _, event in ipairs(events) do
         if event.type == "renamed" then
            print("rename", event.old_path, "->", event.new_path)
         elseif event.type == "created" then
            print("created", event.path)
         elseif event.type == "deleted" then
            print("deleted", event.path)
         elseif event.type == "changed" then
            print("changed", event.path)
         end
      end
   end)
end)

require("obsidian.media-db").setup({
   apis = {
      omdb = { key = "debaf6f7" },
      -- giant_bomb = { key = "0d3deb61eeed923a919def933ceeb4d168fa3f64" },
      spotify = {
         id = os.getenv("SPOTIFY_CLIENT_ID"),
         secret = os.getenv("SPOTIFY_CLIENT_SECRET"),
      },
      open_library = { enabled = false },
      google_books = { key = "AIzaSyBiJEfKGhJ8PMrb2lSrFMSNgYUbvqZdBaM" },
   },
   media_types = {
      movie = {
         field_mappings = {
            director = { format = "[[%s]]" },
            actors = { format = "[[%s]]" },
         },
      },
      musicRelease = {
         field_mappings = {
            artists = { format = "[[%s]]" },
         },
      },
   },
})

require("obsidian.spaced-repetition").setup({
   auto_next_note = true,
})

vim.ui.open = (function(overridden)
   return function(uri, opt)
      if vim.endswith(uri, ".pdf") then
         opt = { cmd = { "zathura" } } -- override open app
      end
      if obsidian.api.get_os() == "Wsl" then
         opt = { cmd = { "wsl-open" } }
      end
      return overridden(uri, opt)
   end
end)(vim.ui.open)

vim.filetype.add({
   extension = {
      base = "yaml",
   },
})

local workspaces = {
   {
      name = "notes",
      path = "~/Documents/Notes/",
   },
   {
      name = "blog",
      path = "~/quarto-blog/posts/",
   },
   {
      name = "config",
      path = "~/.config/nvim/",
   },
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

require("obsidian.due_display")
require("obsidian.yaml_vim_options")
local _actions = require("obsidian._actions")
local ut = require("obsidian._utils")

vim.keymap.set({ "i", "t" }, "<C-S-x>", ut.create_new_from_picker_prompt)

---@type table<string, obsidian.BacklinkMatch[]>
local linked_mentions_cache = {}

---@param match obsidian.BacklinkMatch
---@return string, integer, integer, string
local function backlink_sort_key(match)
   local rel_path = obsidian.Path.new(match.path):vault_relative_path() or tostring(match.path)
   return rel_path, match.line or 0, match.start or 0, match.text or ""
end

---@param matches obsidian.BacklinkMatch[]
---@return obsidian.BacklinkMatch[]
local function sort_backlink_matches(matches)
   table.sort(matches, function(a, b)
      local a_path, a_line, a_start, a_text = backlink_sort_key(a)
      local b_path, b_line, b_start, b_text = backlink_sort_key(b)

      if a_path ~= b_path then
         return a_path < b_path
      elseif a_line ~= b_line then
         return a_line < b_line
      elseif a_start ~= b_start then
         return a_start < b_start
      else
         return a_text < b_text
      end
   end)

   return matches
end

obsidian.setup({
   bookmarks = {
      group = true,
   },

   sync = { enabled = true },

   footer = {
      format = "{{status}}\n{{linked_mentions}}",
      substitutions = {
         linked_mentions = function(note, update)
            local path = tostring(note.path)
            if update or linked_mentions_cache[path] == nil then
               linked_mentions_cache[path] = sort_backlink_matches(note:backlinks({}))
            end
            local matches = linked_mentions_cache[path]

            if #matches == 0 then
               return {}
            end

            local lines = { "Linked Mentions", "" }
            for _, match in ipairs(matches) do
               local rel_path = obsidian.Path.new(match.path):vault_relative_path() or tostring(match.path)
               lines[#lines + 1] = string.format("%s: %s", rel_path, match.text or "")
            end

            return lines
         end,
      },
   },

   completion = {
      min_chars = 2,
   },

   callbacks = {

      ---@param note obsidian.Note
      enter_note = function(note)
         require("obsidian._paste")() -- override paste handler

         local actions = require("obsidian.actions")

         if vim.b[note.bufnr].obsidian_help then
            vim.bo[note.bufnr].readonly = false
         end

         pcall(function()
            vim.keymap.set("n", "<leader>A", actions.add_attachment, { buffer = true })
         end)

         pcall(function()
            vim.keymap.set("n", "<leader>W", actions.workspace_symbol, { buffer = true })
         end)

         pcall(function()
            vim.keymap.set("n", "<leader>ul", actions.unique_link, { buffer = true })
         end)

         pcall(function()
            vim.keymap.set("n", "<leader>xt", _actions.extract_text, { buffer = true })
         end)

         -- vim.keymap.set("n", "<Tab>", actions.cycal_global_headings, { buffer = true })

         vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { buffer = true })
         vim.keymap.set("n", "<leader>p", function()
            if pcall(require, "obsidian.paste") then
               return "<cmd>Obsidian paste<cr>"
            else
               return "<cmd>Obsidian paste_img<cr>"
            end
         end, { buffer = true, expr = true })

         pcall(function()
            vim.keymap.set("n", "<leader>;", obsidian.api.add_property, { buffer = true })
            -- vim.keymap.set("n", "<leader>S", actions.start_presentation, { buffer = true })
         end)

         pcall(function()
            vim.keymap.set("n", "<leader>il", actions.insert_link, {
               buffer = true,
            })
            vim.keymap.set("n", "<leader>it", actions.insert_tag, {
               buffer = true,
            })
            vim.keymap.set("n", "<leader>ta", actions.tag_note, {
               buffer = true,
            })
         end)

         if vim.endswith(tostring(note.path), "todo.md") then
            vim.keymap.del("n", "<CR>", { buffer = true })
            vim.keymap.set("n", "<CR>", "<cmd>Checkmate toggle<cr>", { buffer = true })
         end

         vim.keymap.set("n", "<leader>cb", obsidian.api.set_checkbox, { buffer = true, desc = "Obsidian set checkbox" })

         vim.keymap.set(
            { "n", "x" },
            "<leader>cc",
            obsidian.api.toggle_checkbox,
            { buffer = true, desc = "Obsidian toggle checkbox" }
         )
      end,
   },

   frontmatter = {
      func = function(note)
         local out = require("obsidian.builtin").frontmatter(note)
         if note.metadata and note.metadata.progress then
            local res = ut.count_checkbox(note)
            out.progress = string.format("%d/%d", res.done, res.total)
         end
         if vim.tbl_isempty(note.aliases) then
            out.aliases = nil
         end
         if vim.tbl_isempty(note.tags) then
            out.tags = nil
         end
         if #note.aliases == 1 and note.aliases[1] == note.id then
            out.aliases = nil
         end
         if note.id == note.path.stem then
            out.id = nil
         end
         return out
      end,
      ---@type fun(note: obsidian.Note): table<string, any>
      func = function(note)
         local out = {}
         local has_metadata = note.metadata ~= nil and not vim.tbl_isempty(note.metadata)

         if has_metadata then
            for k, v in pairs(note.metadata) do
               out[k] = v
            end
         end

         vim.notify(string.format("exists ? %d", note:exists() and 1 or 0))

         if not note:exists() and out["created"] == nil then
            out.created = os.date("%Y-%m-%d")
         end

         out.last_modified = os.date("%Y-%m-%d")

         return out
      end,
      enabled = function(path)
         if tostring(path):find("draft") then
            return false
         end
         if vim.endswith(tostring(path), ".qmd") then
            return false
         end

         if Obsidian.workspace.name == "wiki" then
            return false
         end

         return true
      end,
   },

   -- lsp = {
   --    hover = {
   --       note_preview_callback = function(note)
   --          local contents = {}
   --          for i = 1, 20 do
   --             contents[i] = note.contents[i]
   --          end
   --          return contents
   --       end,
   --    },
   -- },

   legacy_commands = false,

   link = {
      format = "shortest",
      -- format = "absolute",
      -- format = "relative",
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
      order = { " ", "x" },
      create_new = true,
   },

   open = {
      use_advanced_uri = false,
      schemes = {
         "zotero",
      },
   },

   daily_notes = {
      enabled = true,
      template = "daily.md",
      folder = "Daily",
      default_tags = {},
      workdays_only = false,
   },

   picker = {
      -- enabled = false,
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
      folder = "./Attachments",
      -- pick = function(callback)
      --    Obsidian.picker.find_files({
      --       dir = "~",
      --       callback = function(path)
      --          callback(path)
      --       end,
      --    })
      -- end,
   },

   templates = {
      folder = "Templates",
      date_format = "%Y-%m-%d",
      time_format = "%H:%M",
   },

   unique_note = {
      folder = "Zettel",
      template = "unique.md",
   },

   note = {
      template = "default.md",
   },

   workspaces = workspaces,
})
