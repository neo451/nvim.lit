local api = require("obsidian.api")
local Header = require("obsidian.parse.header")
local log = require("obsidian.log")

---@class obsidian.actions.CopyLinkOpts
---@field register string|? register receiving the link, defaults to `+`
---@field target "auto"|"note"|"heading"|"block"|? target under the cursor

---@param note obsidian.Note
---@param row integer 0-indexed
---@return obsidian.note.Block?
local function block_at_row(note, row)
   for _, block in pairs(note.blocks or {}) do
      local section = block.section
      if section and section.range.start_row <= row and row < section.range.end_row then
         return block
      end
   end
end

---@param lines string[]
---@param row integer 0-indexed
---@param note obsidian.Note
---@return integer? 0-indexed paragraph end row
local function paragraph_end(lines, row, note)
   if note.frontmatter_end_line and row < note.frontmatter_end_line then
      return
   end

   local fenced = false
   for i = 1, row + 1 do
      if (lines[i] or ""):match("^%s*```") then
         fenced = not fenced
      end
   end
   local line = lines[row + 1] or ""
   if fenced or vim.trim(line) == "" or Header.parse(line) then -- TODO: api.on_heading?
      return
   end

   local list_indent = line:match("^(%s*)[-+*]%s+") or line:match("^(%s*)%d+[.)]%s+")
   local last = row
   for i = row + 2, #lines do
      local next_line = lines[i] or ""
      if vim.trim(next_line) == "" or Header.parse(next_line) or next_line:match("^%s*```") then
         break
      end

      local next_indent = next_line:match("^(%s*)[-+*]%s+") or next_line:match("^(%s*)%d+[.)]%s+")
      if (not list_indent and next_indent) or (list_indent and next_indent and #next_indent <= #list_indent) then
         break
      end
      last = i - 1
   end
   return last
end

---@param note obsidian.Note
---@return string
local function new_block_id(note)
   local chars = "abcdefghijklmnopqrstuvwxyz0123456789"
   while true do
      local id = "^"
      for _ = 1, 6 do
         local idx = math.random(#chars)
         id = id .. chars:sub(idx, idx)
      end
      if not (note.blocks or {})[id] then
         return id
      end
   end
end

---Copy an internal link to the current note, heading, or paragraph.
---@param opts obsidian.actions.CopyLinkOpts|?
---@return string?
local copy_link = function(opts)
   opts = opts or {}
   local bufnr = vim.api.nvim_get_current_buf()
   local row = vim.api.nvim_win_get_cursor(0)[1] - 1
   local note = api.current_note(bufnr, { collect_blocks = true })
   if not note then
      return log.warn("Not in an obsidian note")
   end

   local target = opts.target or "auto"
   ---@type obsidian.link.LinkCreationOpts
   local link_opts = {}
   if target == "auto" or target == "heading" then
      local heading = api.cursor_heading()
      if heading then
         ---@cast heading obsidian.note.HeaderAnchor
         link_opts.anchor = heading
      end
   end

   if not link_opts.anchor and (target == "auto" or target == "block") then
      local block = block_at_row(note, row)
      if not block then
         local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
         local end_row = paragraph_end(lines, row, note)
         if end_row then
            local id = new_block_id(note)
            local line = (lines[end_row + 1] or ""):gsub("%s+$", "") .. " " .. id
            vim.api.nvim_buf_set_lines(bufnr, end_row, end_row + 1, false, { line })
            block = { id = id, line = end_row + 1, block = line }
         end
      end
      link_opts.block = block
   end

   local link = note:format_link(link_opts)
   vim.fn.setreg(opts.register or "+", link)
   log.info("Copied link: %s", link)
   return link
end

require("obsidian").code_action.add({
   name = "copy_link",
   title = "Copy link to loaction",
   fn = copy_link,
})

-- TODO: add a footnote link mode.
local function copy_file()
   local bufnr = vim.api.nvim_get_current_buf()
   local note = api.current_note(bufnr)
   if not note then
      return log.warn("Not in an obsidian note")
   end
   if not note.path then
      return log.warn("Cannot resolve the current note path")
   end

   local path = note.path
   local vault_path = path:vault_relative_path({ strict = true })
   local workspace_dir = api.resolve_workspace_dir(tostring(path))
   local vault_name = vim.fs.basename(tostring(workspace_dir))
   local modes = {
      "File link",
      "File embed",
      "Obsidian URI",
      "Vault-relative path",
      "Absolute path",
   }

   vim.ui.select(modes, { prompt = "Copy file as:" }, function(mode)
      if not mode then
         return
      end

      local value
      if mode == "File link" then
         value = note:format_link()
      elseif mode == "File embed" then
         value = "!" .. note:format_link()
      elseif mode == "Obsidian URI" then
         local uri_path = vault_path
         if api.get_os() == api.OSType.Windows then
            uri_path = uri_path:gsub("/", "\\\\")
         end
         value = ("obsidian://open?vault=%s&file=%s"):format(vim.uri_encode(vault_name), vim.uri_encode(uri_path))
      elseif mode == "Vault-relative path" then
         value = vault_path
      else
         value = tostring(path)
      end

      vim.fn.setreg("+", value)
      log.info("Copied %s: %s", mode:lower(), value)
   end)
end

require("obsidian").code_action.add({
   name = "copy_file",
   title = "Copy file link",
   fn = copy_file,
})
