local api = require("obsidian.api")
local search = require("obsidian.search")
local Note = require("obsidian.note")

local buffer_attach = function(buf)
   vim.b[buf].obsidian_buffer = true
   vim.bo[buf].includeexpr = "v:lua.require('obsidian.link').includeexpr(v:fname)"

   -- Register keymap.
   vim.keymap.set("n", "<CR>", api.smart_action, { expr = true, buffer = buf, desc = "Obsidian Smart Action" })

   vim.keymap.set("n", "]o", function()
      api.nav_link("next")
   end, { buffer = buf, desc = "Obsidian Next Link" })

   vim.keymap.set("n", "[o", function()
      api.nav_link("prev")
   end, { buffer = buf, desc = "Obsidian Previous Link" })

   require("obsidian.lsp").start(buf)
end

---@class obsidian.Sidebar
---@field buf integer
---@field win integer
---@field mode string
---@field source_buf integer
local Sidebar = {}
Sidebar.__index = Sidebar

-- module-level ref so the winbar click callback can reach the active sidebar
local _current = nil

local MODES = { "tags", "links", "backlinks", "outline", "footnotes" }
local MODE_KEYS = { T = "tags", L = "links", B = "backlinks", O = "outline", F = "footnotes" }

-- ─── winbar ───────────────────────────────────────────────────────────────────

local function setup_hl()
   vim.api.nvim_set_hl(0, "ObsidianSidebarTab", { link = "TabLine" })
   vim.api.nvim_set_hl(0, "ObsidianSidebarTabSel", { link = "TabLineSel" })
end

-- Called by winbar click: v:lua.require'obsidian.ui.sidebar'.select_tab(idx)
function Sidebar.select_tab(idx)
   if _current and MODES[idx] then
      _current:refresh(MODES[idx])
   end
end

---@param self obsidian.Sidebar
local function update_winbar(self)
   setup_hl()
   local parts = {}
   for i, m in ipairs(MODES) do
      local label = " " .. m:sub(1, 1):upper() .. m:sub(2) .. " "
      local clickable = "%" .. i .. "@v:lua.require'obsidian.ui.sidebar'.select_tab@" .. label
      if self.mode == m then
         parts[#parts + 1] = "%#ObsidianSidebarTabSel#" .. clickable .. "%*%X"
      else
         parts[#parts + 1] = "%#ObsidianSidebarTab#" .. clickable .. "%*%X"
      end
   end
   vim.api.nvim_set_option_value("winbar", table.concat(parts, ""), { win = self.win })
end

-- ─── helpers ──────────────────────────────────────────────────────────────────

local function set_lines(buf, lines)
   vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
   vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
end

-- ─── tags ─────────────────────────────────────────────────────────────────────

---@param tag_locations obsidian.TagLocation[]
---@return table
local function build_tag_tree(tag_locations)
   ---@type table<string, integer>
   local leaf_counts = {}
   for _, tag_loc in ipairs(tag_locations) do
      leaf_counts[tag_loc.tag] = (leaf_counts[tag_loc.tag] or 0) + 1
   end

   local root = {}

   local function get_or_create(node, key)
      if not node[key] then
         node[key] = { count = 0, children = {} }
      end
      return node[key]
   end

   for tag, count in pairs(leaf_counts) do
      local parts = vim.split(tag, "/", { plain = true })
      local cur = root
      for _, part in ipairs(parts) do
         local entry = get_or_create(cur, part)
         entry.count = entry.count + count
         cur = entry.children
      end
   end

   return root
end

---@param tree table
---@param lines string[]
---@param prefix string
---@param depth integer
local function render_tag_tree(tree, lines, prefix, depth)
   local keys = vim.tbl_keys(tree)
   table.sort(keys)
   for _, key in ipairs(keys) do
      local entry = tree[key]
      local full_tag = prefix == "" and key or (prefix .. "/" .. key)
      lines[#lines + 1] = string.rep("  ", depth) .. "- #" .. full_tag
      if next(entry.children) then
         render_tag_tree(entry.children, lines, full_tag, depth + 1)
      end
   end
end

-- ─── links ────────────────────────────────────────────────────────────────────

---@param note obsidian.Note
---@return string[]
local function render_links(note)
   local link_matches = note:links()
   if vim.tbl_isempty(link_matches) then
      return { "_No outgoing links._" }
   end
   local lines = {}
   for _, m in ipairs(link_matches) do
      lines[#lines + 1] = "- " .. m.link
   end
   return lines
end

-- ─── backlinks ────────────────────────────────────────────────────────────────

---@param note obsidian.Note
---@param dir obsidian.Path
---@param callback fun(lines: string[])
local function render_backlinks_async(note, dir, callback)
   search.find_backlinks_async(note, function(matches)
      if vim.tbl_isempty(matches) then
         callback({ "_No backlinks found._" })
         return
      end
      ---@type table<string, boolean>
      local seen = {}
      local lines = {}
      for _, m in ipairs(matches) do
         local p = tostring(m.path)
         if not seen[p] then
            seen[p] = true
            lines[#lines + 1] = "- [[" .. vim.fn.fnamemodify(p, ":t:r") .. "]]"
         end
      end
      table.sort(lines)
      callback(lines)
   end, { dir = dir })
end

-- ─── outline ──────────────────────────────────────────────────────────────────

---@param note obsidian.Note
---@return string[]
local function render_outline(note)
   local n = Note.from_file(note.path, { collect_anchor_links = true })
   if not n.anchor_links or vim.tbl_isempty(n.anchor_links) then
      return { "_No headings found._" }
   end
   local anchors = vim.tbl_values(n.anchor_links)
   table.sort(anchors, function(a, b)
      return a.line < b.line
   end)
   local lines = {}
   for _, anchor in ipairs(anchors) do
      lines[#lines + 1] = string.rep("  ", anchor.level - 1) .. "- [[#" .. anchor.header .. "]]"
   end
   return lines
end

-- ─── footnotes ────────────────────────────────────────────────────────────────

---@param bufnr integer
---@return string[]
local function render_footnotes(bufnr)
   local defs = {}
   for _, l in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
      local label, rest = l:match("^%[%^([^%]]+)%]:%s*(.*)")
      if label then
         defs[#defs + 1] = { label = label, text = rest }
      end
   end
   if vim.tbl_isempty(defs) then
      return { "_No footnotes found._" }
   end
   local lines = {}
   for _, def in ipairs(defs) do
      local preview = def.text ~= "" and (" — " .. def.text) or ""
      lines[#lines + 1] = "- [^" .. def.label .. "]" .. preview
   end
   return lines
end

-- ─── refresh ──────────────────────────────────────────────────────────────────

---@param mode string
function Sidebar:refresh(mode)
   self.mode = mode
   update_winbar(self)

   if mode == "tags" then
      local workspace = api.find_workspace(vim.api.nvim_buf_get_name(self.source_buf)) or Obsidian.workspace
      search.find_tags_async("", function(tag_locations)
         local lines = {}
         render_tag_tree(build_tag_tree(tag_locations), lines, "", 0)
         vim.schedule(function()
            set_lines(self.buf, lines)
         end)
      end, { dir = workspace.root })
   elseif mode == "links" then
      set_lines(self.buf, render_links(Note.from_buffer(self.source_buf)))
   elseif mode == "backlinks" then
      local note = Note.from_buffer(self.source_buf)
      local workspace = api.find_workspace(vim.api.nvim_buf_get_name(self.source_buf)) or Obsidian.workspace
      render_backlinks_async(note, workspace.root, function(lines)
         vim.schedule(function()
            set_lines(self.buf, lines)
         end)
      end)
   elseif mode == "outline" then
      set_lines(self.buf, render_outline(Note.from_buffer(self.source_buf)))
   elseif mode == "footnotes" then
      set_lines(self.buf, render_footnotes(self.source_buf))
   end
end

-- ─── open ─────────────────────────────────────────────────────────────────────

---@param mode string
---@param source_buf integer
---@return obsidian.Sidebar
function Sidebar.open(mode, source_buf)
   local buf = vim.api.nvim_create_buf(false, true)
   local win = vim.api.nvim_open_win(buf, false, {
      split = "right",
      width = 80,
   })
   vim.api.nvim_set_option_value("winfixwidth", true, { win = win })
   vim.api.nvim_set_option_value("filetype", "markdown", { buf = buf })
   vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
   vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
   vim.api.nvim_set_option_value("spell", false, { win = win })
   buffer_attach(buf)

   ---@type obsidian.Sidebar
   local self = setmetatable({ buf = buf, win = win, mode = mode, source_buf = source_buf }, Sidebar)
   _current = self

   local map = function(key, fn)
      vim.keymap.set("n", key, fn, { noremap = true, nowait = true, buffer = buf })
   end

   map("q", function()
      vim.api.nvim_win_close(win, true)
      _current = nil
   end)

   -- <Tab> cycles forward through modes
   map("<Tab>", function()
      local idx = vim.fn.index(MODES, self.mode) + 1 -- fn.index is 0-based
      self:refresh(MODES[(idx % #MODES) + 1])
   end)

   -- Uppercase direct jumps
   for key, m in pairs(MODE_KEYS) do
      local m_ref = m
      map(key, function()
         self:refresh(m_ref)
      end)
   end

   self:refresh(mode)
   return self
end

return Sidebar
