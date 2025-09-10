local workspaces = {}

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
   callbacks = {
      -- enter_note = function()
      --    vim.keymap.set("n", "<leader>cb", require("obsidian.api").set_checkbox)
      -- end,
   },
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

   note_id_func = function(title, path)
      return title or vim.fs.basename(tostring(path))
   end,

   disable_frontmatter = function()
      if Obsidian.workspace.name == "obsidian.nvim.wiki" then
         return true
      end
      return false
   end,

   comment = {
      enabled = true,
   },

   ui = {
      enable = false,
   },

   checkbox = {
      order = { "x", " " },
      create_new = false,
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

   workspaces = workspaces,
})
