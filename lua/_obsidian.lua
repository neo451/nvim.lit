local workspaces = {
   {
      path = "~/this-dont-exist",
   },
   -- {
   --    name = "no-vault",
   --    path = function()
   --       -- alternatively use the CWD:
   --       -- return assert(vim.fn.getcwd())
   --       return assert(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
   --    end,
   --    overrides = {
   --       notes_subdir = vim.NIL, -- have to use 'vim.NIL' instead of 'nil'
   --       new_notes_location = "current_dir",
   --       templates = { folder = vim.NIL },
   --       disable_frontmatter = true,
   --    },
   -- },
}

local VAULTS = "~/Vaults/"

local overrides = {
   -- ["obsidian.wiki"] = {
   --    disable_frontmatter = true,
   -- },
}

for dir, t in vim.fs.dir(VAULTS) do
   if t == "directory" then
      local spec = {
         path = vim.fs.joinpath(VAULTS, dir),
      }
      if overrides[dir] then
         spec.overrides = overrides[dir]
      end
      workspaces[#workspaces + 1] = spec
   end
end

require("obsidian").setup({
   frontmatter = {
      sort = false,
      func = function(note)
         local out = { id = note.id, tags = note.tags }
         for k, v in pairs(note.metadata or {}) do
            out[k] = v
         end
         return out
      end,
      enabled = function()
         if Obsidian.workspace.name == "obsidian.nvim.wiki" then
            return false
         end
         return true
      end,
   },

   lsp = {
      hover = {
         note_preview_callback = function(note)
            note:load_contents()
            local contents = {}
            for i = 1, 20 do
               contents[i] = note.contents[i]
            end
            return contents
         end,
      },
   },

   callbacks = {
      enter_note = function()
         vim.keymap.set("n", "<leader>cb", require("obsidian.api").set_checkbox)
      end,
   },
   legacy_commands = false,
   -- prefer_config_from_obsidian_app = true,

   templater = {
      commands = {
         hi = "hello",
      },
   },

   statusline = {
      enabled = false,
   },

   -- note_frontmatter_func = function(note)
   --    local out = { id = note.id, tags = note.tags }
   --    for k, v in pairs(note.metadata or {}) do
   --       out[k] = v
   --    end
   --    return out
   -- end,
   --
   note_id_func = function(title, path)
      return title
   end,

   -- disable_frontmatter = function()
   --    if Obsidian.workspace.name == "obsidian.nvim.wiki" then
   --       return true
   --    end
   --    return false
   -- end,
   --
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
      date_format = "%Y-%m-%d",
      -- template = "journaling-daily-note.md",
      folder = "daily_notes",
   },

   calendar = {
      cmd = "CalendarT",
      close_after = true,
   },

   picker = {
      name = "telescope.nvim",
   },

   attachments = {
      func = function(uri)
         vim.ui.open(uri)
      end,
      confirm_img_paste = false,
      folder = "./attachments",
      img_folder = "./attachments",
   },

   templates = {
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
