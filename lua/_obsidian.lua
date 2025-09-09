require("obsidian").setup({
   legacy_commands = false,
   -- prefer_config_from_obsidian_app = true,

   templater = {
      commands = {
         hi = "hello",
      },
   },

   note_frontmatter_func = function(note)
      local out = { id = note.id, tags = note.tags }
      for k, v in pairs(note.metadata or {}) do
         out[k] = v
      end
      return out
   end,

   -- note_id_func = function(title, path)
   --    return title or vim.fs.basename(tostring(path))
   -- end,

   comment = {
      enabled = true,
   },

   ui = {
      enable = false,
   },

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
      name = "snacks.pick",
   },

   attachments = {
      func = function(uri)
         vim.ui.open(uri)
      end,
      confirm_img_paste = false,
      folder = "./attachments",
      img_folder = "./attachments",
   },

   -- note_id_func = function(title)
   -- 	return title
   -- end,

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

   workspaces = {
      {
         name = "notes",
         path = "~/Vaults/Notes",
      },
      {
         name = "test",
         path = "~/Vaults/test",
      },
      -- {
      -- 	name = "cosma-test",
      -- 	path = "~/Vaults/cosma-test/",
      -- },
      -- {
      -- 	name = "work",
      -- 	path = "~/Vaults/Work",
      -- },
      -- {
      -- 	name = "hub",
      -- 	path = "~/Vaults/obsidian-hub/",
      -- },
      -- {
      --   name = "stress test",
      --   path = "~/.local/share/nvim/nightmare_vault/",
      -- },
   },
})
