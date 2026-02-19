local obsidian = require("obsidian")

vim.ui.open = (function(overridden)
   return function(uri, opt)
      if vim.endswith(uri, ".pdf") then
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

obsidian.setup({
   bookmarks = {
      group = true,
   },

   completion = {
      min_chars = 2,
   },

   note = {
      template = "default.md",
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
            vim.keymap.set("v", "<leader>nd", function()
               require("nldates").parse({
                  callback = function(datestring)
                     return "[[" .. datestring .. "]]"
                  end,
               })
            end)
            vim.keymap.set("n", "<leader>;", obsidian.api.add_property, { buffer = true })
         end)

         pcall(function()
            vim.keymap.set("n", "<leader>S", actions.start_presentation, { buffer = true })
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
      post_setup = function()
         local subcommands = require("obsidian._commands")
         for name, command in pairs(subcommands) do
            obsidian.register_command(name, command)
         end

         -- refresh tags
         subcommands.refresh_tags.func()
      end,
   },

   frontmatter = {
      func = function(note)
         local out = require("obsidian.builtin").frontmatter(note)
         if note.id == "Douban" then
            out.count = ut.count_checkbox(note, "^%d*%. ") .. "/250"
         elseif note.id == "TSPDT" then
            out.count = ut.count_checkbox(note, "^%d*%. %[x%]") .. "/1000"
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
   -- prefer_config_from_obsidian_app = true,

   link = {
      format = "shortest",
      -- format = "relative",
      -- style = "markdown",
      style = "wiki",
   },

   -- templater = {
   --    commands = {
   --       hi = "hello",
   --    },
   -- },
   --
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
      use_advanced_uri = false,
      schemes = {
         "zotero",
      },
   },

   daily_notes = {
      enabled = true,
      -- template = "daily.md",
      folder = "Daily",
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
      folder = "./Attachments",
   },

   templates = {
      -- folder = "Templates",
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
