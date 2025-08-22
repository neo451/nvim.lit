require("obsidian").setup({
   legacy_commands = false,
   -- prefer_config_from_obsidian_app = true,

   note_id_func = function(title, path)
      return title or vim.fs.basename(tostring(path))
   end,

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
      func = function(uri)
         vim.ui.open(uri, { cmd = { "wsl-open" } })
      end,
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
      confirm_img_paste = false,
      img_folder = "./imgs",
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
               print(title)
               return title
            end,
         },
      },
   },

   completion = {
      blink = true,
      nvim_cmp = false,
      -- blink = vim.g.my_cmp == "blink",
      -- nvim_cmp = vim.g.my_cmp == "cmp",
   },

   workspaces = {
      {
         name = "notes",
         path = "~/Vaults/Notes",
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
