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

local function add_property()
   local note = assert(obsidian.api.current_note(0))

   vim.cmd([[
function! ObsidianPropertyComplete(A, L, P)
  return ['aliases', 'tags', 'id']
endfunction
   ]])

   local key = obsidian.api.input("key: ", {
      completion = "customlist,ObsidianPropertyComplete",
   })
   local opts = {}

   if handlers[key] then
      handlers[key]()
      opts.completion = "customlist,ObsidianTagsComplete"
   end

   local value = obsidian.api.input("value: ", opts)

   if not key or not value then
      return obsidian.log.info("Aborted")
   end

   if key == "tags" then
      note:add_tag(value)
      note:update_frontmatter(0)
      return
   end

   note:add_field(key, value)
   note:update_frontmatter(0)
end

local workspaces = {
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
      local spellfile = Obsidian.workspace.root / ".en.utf-8.add"
      if not spellfile:exists() then
         vim.fn.writefile({}, tostring(spellfile))
      end
      vim.bo[note.bufnr].spellfile = tostring(spellfile)
   end,
})

obsidian.setup({

   completion = {
      min_chars = 2,
   },

   -- log_level = vim.log.levels.WARN,
   -- open_notes_in = "vsplit",

   frontmatter = {
      func = function(note)
         local out = require("obsidian.builtin").frontmatter(note)
         out.modified = os.date("%Y-%m-%d %H:%M")
         if note.id == "albums2025" then
            note:load_contents()
            local count = 0
            for _, line in ipairs(note.contents) do
               if line:match("^%d*%. ") then
                  count = count + 1
               end
            end
            out.count = count
         elseif note.id == "nvim" then
            note:load_contents()
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
      enabled = function()
         if string.find(Obsidian.workspace.name, "obsidian.nvim.wiki", 1, true) then
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
         vim.keymap.set("n", "<C-]>", vim.lsp.buf.definition, { buffer = true })
         vim.keymap.set("n", "<leader>p", "<cmd>Obsidian paste_img<cr>", { buffer = true })

         vim.keymap.set("v", "<leader>nd", function()
            require("nldates").parse({
               callback = function(datestring)
                  return "[[" .. datestring .. "]]"
               end,
            })
         end)

         pcall(function()
            vim.keymap.set("v", "<leader>nd", function()
               require("nldates").parse({
                  callback = function(datestring)
                     return "[[" .. datestring .. "]]"
                  end,
               })
            end)
         end)

         vim.keymap.set("n", "fl", function()
            require("flash").jump({
               search = { mode = "search" },
               pattern = "\\[\\[.\\{-}\\]\\]",
            })
         end, { noremap = true, silent = true, buffer = true, desc = "Show wiki-links hints" })
         if vim.endswith(tostring(note.path), "todo.md") then
            vim.keymap.del("n", "<CR>", { buffer = true })
            vim.keymap.set("n", "<CR>", "<cmd>Checkmate toggle<cr>", { buffer = true })
         end

         vim.keymap.set("n", "<leader>;", add_property)

         vim.keymap.set("n", "<leader>cb", require("obsidian.api").set_checkbox)
      end,
   },
   legacy_commands = false,
   -- prefer_config_from_obsidian_app = true,

   link = {
      -- format = "shortest",
      format = "relative",
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

   note_id_func = function(title, path)
      title = title:lower()
      return title
   end,

   comment = { enabled = false },

   ui = { enable = false },

   checkbox = {
      order = { "x", " " },
      create_new = true,
   },

   follow_img_func = function(uri)
      return vim.ui.open(uri, { cmd = { "wsl-open" } })
   end,
   open = {
      use_advanced_uri = true,
      func = function(uri)
         return vim.ui.open(uri, { cmd = { "wsl-open" } })
      end,
   },

   daily_notes = {
      date_format = "%Y-%m-%d",
      template = "daily.md",
      folder = "daily_notes",
   },

   picker = {
      -- enabled = false,
      -- name = false,
      -- name = "mini.pick",
      -- name = "snacks.pick",
      name = "fzf-lua",
      -- name = "telescope.nvim",
   },

   attachments = {
      func = function(uri)
         vim.ui.open(uri)
      end,
      confirm_img_paste = false,
      folder = "./attachments",
      -- img_folder = "./attachments",
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
