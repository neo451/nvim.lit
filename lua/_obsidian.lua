-- vim.api.nvim_create_autocmd("User", {
--    pattern = "ObsidianNoteEnter",
--    callback = function(ev)
--       local file = vim.api.nvim_buf_get_name(ev.buf)
--       if vim.fs.basename(file) == "albums 2025.md" then
--       end
--    end,
-- })

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
   {
      name = "auto",
      path = function()
         local path = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
         local prev = ""
         while path ~= "" and path ~= prev do
            if vim.uv.fs_stat(path .. "/.obsidian") then
               return path
            end
            prev, path = path, vim.fs.dirname(path)
         end
         return nil
      end,
   },
}

local VAULTS = "~/Vaults/"

local overrides = {}

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

local function count_list_items(buf)
   local parser = vim.treesitter.get_parser(buf)
   local tree = parser:parse()[1]:root()
   for i, k in tree:iter_children() do
      print(i, k)
   end
end

require("obsidian").setup({

   -- log_level = vim.log.levels.WARN,
   -- open_notes_in = "vsplit",

   ---@param opts { path: string, label: string, id: string|integer|?, anchor: obsidian.note.HeaderAnchor|?, block: obsidian.note.Block|? }
   ---@return string
   markdown_link_func = function(opts)
      local util = require("obsidian.util")
      local anchor = ""
      local header = ""
      if opts.anchor then
         anchor = opts.anchor.anchor
         header = util.format_anchor_label(opts.anchor)
      elseif opts.block then
         anchor = "#" .. opts.block.id
         header = "#" .. opts.block.id
      end

      local path = util.urlencode(vim.fs.basename(opts.path), { keep_path_sep = true })
      return string.format("[%s%s](%s%s)", opts.label, header, path, anchor)
   end,
   frontmatter = {
      func = function(note)
         local out = require("obsidian.builtin").frontmatter(note)
         out.modified = os.date("%Y-%m-%d %H:%M")
         if note.id == "albums 2025" then
            note:load_contents()
            local count = 0
            for _, line in ipairs(note.contents) do
               if line:match("^%s*%- ") then
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
      enter_note = function(note)
         if vim.endswith(tostring(note.path), "todo.md") then
            vim.keymap.del("n", "<CR>", { buffer = true })
            vim.keymap.set("n", "<CR>", "<cmd>Checkmate toggle<cr>", { buffer = true })
         end

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

   note_id_func = function(title, path)
      return title
   end,

   comment = { enabled = false },

   ui = { enable = false },

   checkbox = {
      order = { "x", " " },
      create_new = true,
   },

   open = {
      use_advanced_uri = true,
      func = function(uri)
         return vim.ui.open(uri, { cmd = { "wsl-open" } })
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
      -- enabled = false,
      -- name = false,
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
