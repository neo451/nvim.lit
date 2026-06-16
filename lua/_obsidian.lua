vim.opt.rtp:append("~/Plugins/obsidian.nvim")
vim.opt.rtp:append("~/Plugins/obsidian-media-db.nvim/")
vim.opt.rtp:append("~/Plugins/obsidian-heatmap.nvim/")
vim.opt.rtp:append("~/Plugins/scribe.nvim/")
vim.opt.rtp:append("~/Plugins/obsidian-spaced-repetition.nvim/")
-- vim.opt.rtp:append("~/Plugins/obsidian-cite.nvim/")

local obsidian = require("obsidian")

--- EXPERIMENTS ---

require("obsidian.due_display")
require("obsidian.yaml_vim_options")
require("obsidian.yazi_attachment")
local ut = require("obsidian._utils")
vim.keymap.set({ "i", "t" }, "<C-S-x>", ut.create_new_from_picker_prompt)
vim.filetype.add({
   extension = {
      base = "yaml",
   },
})

--- INTEGRATIONS ---

require("obsidian").register_command("heatmap", { nargs = 0 })
require("_obsidian_cite")
require("obsidian.spaced-repetition").setup({
   auto_next_note = true,
})
require("_obsidian_media_db")

--- OPEN ---

local handlers = {
   jisho = function(uri)
      local query = uri:gsub(vim.pesc("jisho://"), "")
      vim.cmd("Jisho " .. query)
   end,
   man = function(uri)
      local query = uri:gsub(vim.pesc("man://"), "")
      vim.cmd("Man " .. query)
   end,
   rfc = function(uri, overridden)
      local rfc_number = uri:gsub(vim.pesc("rfc://"), "")
      rfc_number = tonumber(rfc_number)
      local url = "https://www.rfc-editor.org/rfc/rfc" .. rfc_number .. ".txt"
      overridden(url, { cmd = { "zen-beta" } })
   end,
}

vim.ui.open = (function(overridden)
   return function(uri, opt)
      local ok, scheme = require("obsidian.util").is_uri(uri)
      if ok and handlers[scheme] then
         return handlers[scheme](uri, overridden)
      end
      if vim.endswith(uri, ".pdf") then
         opt = { cmd = { "zathura" } } -- override open app
      end
      if require("obsidian").api.get_os() == "Wsl" then
         opt = { cmd = { "wsl-open" } }
      else
         opt = { cmd = { "zen-beta" } }
      end
      return overridden(uri, opt)
   end
end)(vim.ui.open)

--- SETUP ---

obsidian.setup({
   image = {
      enabeld = true,
   },

   files = {
      trash = "local",
   },

   cache = {
      enabled = true,
      backend = "memory",
      ignore_patterns = {
         "^%.agents/",
         "^Archived/",
      },
   },

   sync = {
      -- trigger = "continuous",
      enabled = true,
   },

   footer = {
      -- TODO: multiline footer
      -- format = "{{status}}\n{{linked_mentions}}",
      substitutions = {
         linked_mentions = require("obsidian._linked_mentions"),
      },
   },

   completion = {
      min_chars = 2,
   },

   backlinks = {
      parse_headers = true,
   },

   callbacks = {
      enter_note = function(note)
         require("obsidian.enter_note")(note)
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
      enabled = function(path)
         if vim.endswith(tostring(path), ".qmd") then
            return false
         end
         return true
      end,
   },

   legacy_commands = false,

   link = {
      resolve = "strict",
      format = "shortest",
   },

   ---@param id string
   ---@return string
   note_id_func = function(id)
      return id
   end,

   comment = { enabled = false },

   ui = { enable = false },

   checkbox = {
      order = { "", " ", "x" },
      create_new = true,
   },

   open = {
      use_advanced_uri = false,
      schemes = { "zotero", "jisho", "man", "rfc" },
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
      name = "snacks.picker",
      -- name = "mini.pick",
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

   workspaces = {
      {
         name = "notes",
         path = "~/Documents/Notes/",
      },
      {
         name = "skills",
         path = "~/.agents/skills/",
         overrides = {
            templates = { enabeld = false },
            daily_notes = { enabeld = false },
         },
      },
      {
         name = "blog",
         path = "~/Documents/blog/posts/",
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
   },
})
