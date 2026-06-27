local M = {}

local function notify(msg, level)
   vim.notify(msg, level or vim.log.levels.INFO, { title = "Obsidian base" })
end

local function trim(s)
   return vim.trim(tostring(s or ""))
end

local function strip_md_suffix(name)
   return name:gsub("%.md$", "")
end

local function clean_tag(tag)
   return tostring(tag):gsub("^#", "")
end

local function unique_append(list, value)
   if value == nil or value == "" then
      return
   end
   if not vim.list_contains(list, value) then
      list[#list + 1] = value
   end
end

local function parse_quoted_arg(s, i)
   local quote = s:sub(i, i)
   local out = {}
   i = i + 1

   while i <= #s do
      local ch = s:sub(i, i)
      if ch == "\\" then
         local next_ch = s:sub(i + 1, i + 1)
         if next_ch ~= "" then
            out[#out + 1] = next_ch
            i = i + 2
         else
            i = i + 1
         end
      elseif ch == quote then
         return table.concat(out), i + 1
      else
         out[#out + 1] = ch
         i = i + 1
      end
   end

   return table.concat(out), i
end

local function parse_bare_arg(s, i)
   local start = i
   while i <= #s and s:sub(i, i) ~= "," do
      i = i + 1
   end

   local value = trim(s:sub(start, i - 1))
   if value == "true" then
      return true, i
   elseif value == "false" then
      return false, i
   elseif tonumber(value) ~= nil then
      return tonumber(value), i
   else
      return value, i
   end
end

local function parse_args(s)
   local args = {}
   local i = 1

   while i <= #s do
      while i <= #s and s:sub(i, i):match("%s") do
         i = i + 1
      end

      if i > #s then
         break
      end

      local ch = s:sub(i, i)
      local value
      if ch == '"' or ch == "'" then
         value, i = parse_quoted_arg(s, i)
      else
         value, i = parse_bare_arg(s, i)
      end
      args[#args + 1] = value

      while i <= #s and s:sub(i, i):match("%s") do
         i = i + 1
      end
      if s:sub(i, i) == "," then
         i = i + 1
      end
   end

   return args
end

---Parse a small Bases expression subset into an AST node.
---Currently supports member calls like `file.inFolder("Folder")`.
---@param expr string
---@return table
function M.parse_expression(expr)
   expr = trim(expr)

   local receiver, method, arg_src = expr:match("^([%w_]+)%.([%w_]+)%((.*)%)$")
   if receiver ~= nil then
      return {
         type = "call",
         receiver = receiver,
         method = method,
         args = parse_args(arg_src),
         source = expr,
      }
   end

   return { type = "raw", source = expr }
end

---Parse a Bases filter YAML value into an AST node.
---@param filter any
---@return table|nil
function M.parse_filter(filter)
   if filter == nil or filter == vim.NIL then
      return nil
   end

   if type(filter) == "string" then
      return M.parse_expression(filter)
   end

   if type(filter) ~= "table" then
      return { type = "literal", value = filter }
   end

   if filter["and"] ~= nil then
      local children = {}
      for _, child in ipairs(filter["and"]) do
         children[#children + 1] = M.parse_filter(child)
      end
      return { type = "group", op = "and", children = children }
   end

   if filter["or"] ~= nil then
      local children = {}
      for _, child in ipairs(filter["or"]) do
         children[#children + 1] = M.parse_filter(child)
      end
      return { type = "group", op = "or", children = children }
   end

   if filter["not"] ~= nil then
      return { type = "not", child = M.parse_filter(filter["not"]) }
   end

   return { type = "raw_table", value = filter }
end

local function walk_filter(node, fn)
   if node == nil then
      return
   end

   fn(node)

   if node.type == "group" then
      for _, child in ipairs(node.children or {}) do
         walk_filter(child, fn)
      end
   elseif node.type == "not" then
      walk_filter(node.child, fn)
   end
end

local function parse_view(view)
   return {
      type = view.type,
      name = view.name,
      raw = view,
      filter = M.parse_filter(view.filters),
      order = view.order or {},
      sort = view.sort or {},
      column_size = view.columnSize or {},
   }
end

local function line_indent(line)
   return #(line:match("^%s*") or "")
end

local function parse_scalar(value)
   value = trim(value)
   if value == "" or value == "null" or value == "~" then
      return vim.NIL
   end

   local ok, parsed = pcall(function()
      return require("obsidian.yaml").loads("x: " .. value).x
   end)
   if ok then
      return parsed
   end

   local quote = value:sub(1, 1)
   if (quote == '"' or quote == "'") and value:sub(-1) == quote then
      return value:sub(2, -2)
   end

   if value == "true" then
      return true
   elseif value == "false" then
      return false
   elseif tonumber(value) ~= nil then
      return tonumber(value)
   else
      return value
   end
end

local function parse_key_value(content)
   local key, value = content:match("^([^:]+):%s*(.*)$")
   if key == nil then
      return nil, nil
   end
   return trim(key), value
end

local parse_yaml_block

local function parse_yaml_mapping(lines, i, indent)
   local out = {}

   while i <= #lines do
      local line = lines[i]
      if line.indent < indent or line.content:match("^%-") then
         break
      end
      if line.indent > indent then
         break
      end

      local key, value = parse_key_value(line.content)
      if key == nil then
         break
      end

      if value ~= "" then
         out[key] = parse_scalar(value)
         i = i + 1
      elseif lines[i + 1] ~= nil and lines[i + 1].indent > indent then
         out[key], i = parse_yaml_block(lines, i + 1, lines[i + 1].indent)
      else
         out[key] = vim.NIL
         i = i + 1
      end
   end

   return out, i
end

local function parse_yaml_array(lines, i, indent)
   local out = {}

   while i <= #lines do
      local line = lines[i]
      if line.indent ~= indent or not line.content:match("^%-") then
         break
      end

      local rest = trim(line.content:gsub("^%-%s*", "", 1))
      if rest == "" then
         if lines[i + 1] ~= nil and lines[i + 1].indent > indent then
            local value
            value, i = parse_yaml_block(lines, i + 1, lines[i + 1].indent)
            out[#out + 1] = value
         else
            out[#out + 1] = vim.NIL
            i = i + 1
         end
      else
         local key, value = parse_key_value(rest)
         if key ~= nil then
            local item = {}
            item[key] = value ~= "" and parse_scalar(value) or vim.NIL
            i = i + 1

            if lines[i] ~= nil and lines[i].indent > indent then
               local more
               more, i = parse_yaml_mapping(lines, i, lines[i].indent)
               for more_key, more_value in pairs(more) do
                  item[more_key] = more_value
               end
            end

            out[#out + 1] = item
         else
            out[#out + 1] = parse_scalar(rest)
            i = i + 1
         end
      end
   end

   return out, i
end

parse_yaml_block = function(lines, i, indent)
   if lines[i] ~= nil and lines[i].content:match("^%-") then
      return parse_yaml_array(lines, i, indent)
   end
   return parse_yaml_mapping(lines, i, indent)
end

local function parse_base_yaml(src)
   local lines = {}
   for raw in src:gmatch("[^\r\n]+") do
      local content = trim(raw)
      if content ~= "" and not content:match("^#") then
         lines[#lines + 1] = { indent = line_indent(raw), content = content }
      end
   end

   if #lines == 0 then
      return {}
   end

   local data = parse_yaml_block(lines, 1, lines[1].indent)
   return data
end

local function load_base_yaml(src)
   local ok, data = pcall(require("obsidian.yaml").loads, src)
   if ok and type(data) == "table" and data.views ~= nil then
      return data
   end

   return parse_base_yaml(src)
end

---Parse a .base YAML string into a small AST for actions.
---@param src string
---@return table
function M.parse(src)
   local data = load_base_yaml(src)
   local ast = { type = "base", raw = data, views = {} }

   for _, view in ipairs((data and data.views) or {}) do
      ast.views[#ast.views + 1] = parse_view(view)
   end

   return ast
end

local function current_buffer_text()
   return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

local function select_view(ast, name)
   if name == nil or name == "" then
      return ast.views[1]
   end

   for _, view in ipairs(ast.views) do
      if view.name == name then
         return view
      end
   end
end

local function is_property_column(column)
   return type(column) == "string" and not column:match("^[%w_]+%.")
end

---Extract enough base semantics to create a matching note.
---@param ast table
---@param view_name string|nil
---@return table
function M.create_spec(ast, view_name)
   local view = select_view(ast, view_name)
   if view == nil then
      error(view_name and ("view not found: " .. view_name) or "base has no views")
   end

   local spec = {
      view = view,
      folder = nil,
      tags = {},
      fields = {},
   }

   walk_filter(view.filter, function(node)
      if node.type ~= "call" or node.receiver ~= "file" then
         return
      end

      if node.method == "inFolder" and spec.folder == nil then
         spec.folder = node.args[1]
      elseif node.method == "hasTag" then
         for _, tag in ipairs(node.args or {}) do
            unique_append(spec.tags, clean_tag(tag))
         end
      end
   end)

   for _, column in ipairs(view.order or {}) do
      if is_property_column(column) then
         unique_append(spec.fields, column)
      end
   end

   return spec
end

local function resolve_folder(folder)
   local Path = require("obsidian.path")
   local path = Path.new(folder)
   if path:is_absolute() then
      return folder
   end

   local buf_name = vim.api.nvim_buf_get_name(0)
   if buf_name ~= "" then
      local workspace = require("obsidian.api").find_workspace(buf_name)
      if workspace ~= nil then
         return tostring(workspace.root / folder)
      end
   end

   return folder
end

local function create_note(filename, spec)
   if filename:find("[/\\]") then
      error("filename must not contain path separators")
   end

   local Note = require("obsidian.note")
   local note = Note.create({
      id = strip_md_suffix(filename),
      dir = resolve_folder(spec.folder),
      tags = spec.tags,
      template = nil,
      verbatim = true,
   })

   for _, field in ipairs(spec.fields) do
      note:add_field(field, "")
   end

   note:write()
   vim.cmd.edit(vim.fn.fnameescape(tostring(note.path)))
   return note
end

local function source_workspace(source_path)
   if source_path ~= nil and source_path ~= "" then
      local workspace = require("obsidian.api").find_workspace(source_path)
      if workspace ~= nil then
         return workspace
      end
   end

   return Obsidian and Obsidian.workspace or nil
end

local function resolve_view_folder(folder, source_path)
   local workspace = source_workspace(source_path)
   if folder == nil or folder == "" then
      if workspace ~= nil then
         return tostring(workspace.root)
      end
      return vim.uv.cwd()
   end

   local Path = require("obsidian.path")
   local path = Path.new(folder)
   if path:is_absolute() then
      return tostring(path)
   end
   if workspace ~= nil then
      return tostring(workspace.root / folder)
   end
   return folder
end

local function list_note_paths(dir)
   local paths = {}

   local function scan(path)
      local iter = vim.fs.dir(path)
      if iter == nil then
         return
      end

      for name, kind in iter do
         if name:sub(1, 1) ~= "." then
            local child = vim.fs.joinpath(path, name)
            if kind == "directory" then
               scan(child)
            elseif kind == "file" and (name:match("%.md$") or name:match("%.markdown$") or name:match("%.qmd$")) then
               paths[#paths + 1] = child
            end
         end
      end
   end

   scan(dir)
   table.sort(paths)
   return paths
end

local function has_all_tags(note, tags)
   for _, tag in ipairs(tags or {}) do
      local wanted = clean_tag(tag)
      local found = false
      for _, note_tag in ipairs(note.tags or {}) do
         if clean_tag(note_tag) == wanted then
            found = true
            break
         end
      end
      if not found then
         return false
      end
   end

   return true
end

local function view_query(view)
   local query = { folder = nil, tags = {} }

   walk_filter(view.filter, function(node)
      if node.type ~= "call" or node.receiver ~= "file" then
         return
      end

      if node.method == "inFolder" and query.folder == nil then
         query.folder = node.args[1]
      elseif node.method == "hasTag" then
         for _, tag in ipairs(node.args or {}) do
            unique_append(query.tags, clean_tag(tag))
         end
      end
   end)

   return query
end

local function column_property(column)
   if type(column) ~= "string" then
      return nil
   end
   if column:match("^note%.") then
      return column:gsub("^note%.", "", 1)
   end
   if not column:match("^[%w_]+%.") then
      return column
   end
end

local function column_label(column)
   if column == "file.name" then
      return "File"
   elseif column == "file.path" then
      return "Path"
   elseif column == "file.folder" then
      return "Folder"
   elseif column == "file.tags" then
      return "Tags"
   elseif type(column) == "string" and column:match("^formula%.") then
      return column:gsub("^formula%.", "", 1)
   end

   return column_property(column) or tostring(column)
end

local function stringify_value(value)
   if value == nil or value == vim.NIL then
      return ""
   end

   if type(value) ~= "table" then
      return tostring(value)
   end

   local values = {}
   if #value > 0 then
      for _, item in ipairs(value) do
         values[#values + 1] = stringify_value(item)
      end
   else
      for key, item in pairs(value) do
         values[#values + 1] = tostring(key) .. ": " .. stringify_value(item)
      end
      table.sort(values)
   end

   return table.concat(values, ", ")
end

local function relative_to_workspace(path, source_path)
   local workspace = source_workspace(source_path)
   if workspace == nil then
      return path
   end

   local ok, rel = pcall(function()
      return require("obsidian.path").new(path):relative_to(workspace.root)
   end)
   if ok and rel ~= nil then
      return tostring(rel)
   end
   return path
end

local function note_value(note, column, source_path)
   local path = note.path
   if column == "file.name" then
      return path and path.stem or note:display_name()
   elseif column == "file.path" then
      return path and relative_to_workspace(tostring(path), source_path) or ""
   elseif column == "file.folder" then
      if path == nil or path:parent() == nil then
         return ""
      end
      return relative_to_workspace(tostring(path:parent()), source_path)
   elseif column == "file.tags" then
      return note.tags or {}
   elseif type(column) == "string" and column:match("^formula%.") then
      return ""
   end

   local prop = column_property(column)
   if prop == nil then
      return ""
   elseif prop == "id" then
      return note.id
   elseif prop == "aliases" then
      return note.aliases
   elseif prop == "tags" then
      return note.tags
   end

   return note.metadata and note.metadata[prop] or nil
end

local function display_width(text)
   return vim.fn.strdisplaywidth(text)
end

local function truncate(text, width)
   text = tostring(text or "")
   if display_width(text) <= width then
      return text
   end
   if width <= 1 then
      return "…"
   end

   local out = {}
   local used = 0
   local i = 0
   while i < vim.fn.strchars(text) do
      local ch = vim.fn.strcharpart(text, i, 1)
      local ch_width = display_width(ch)
      if used + ch_width > width - 1 then
         break
      end
      out[#out + 1] = ch
      used = used + ch_width
      i = i + 1
   end

   return table.concat(out) .. "…"
end

local function pad(text, width)
   text = tostring(text or "")
   return text .. string.rep(" ", math.max(width - display_width(text), 0))
end

local function configured_column_width(view, column)
   local sizes = view.column_size or {}
   local candidates = { column }
   local prop = column_property(column)
   if prop ~= nil then
      candidates[#candidates + 1] = "note." .. prop
   end

   for _, key in ipairs(candidates) do
      local px = tonumber(sizes[key])
      if px ~= nil then
         return math.max(6, math.floor(px / 8))
      end
   end
end

local function load_table_model(ast, view, source_path)
   local columns = vim.deepcopy(view.order or {})
   if vim.tbl_isempty(columns) then
      columns = { "file.name" }
   end

   local query = view_query(view)
   local folder = resolve_view_folder(query.folder, source_path)
   local stat = vim.uv.fs_stat(folder)
   if stat == nil or stat.type ~= "directory" then
      error("base folder not found: " .. folder)
   end

   local Note = require("obsidian.note")
   local rows = {}
   for _, path in ipairs(list_note_paths(folder)) do
      local ok, note = pcall(Note.from_file, path, { max_lines = 500 })
      if ok and has_all_tags(note, query.tags) then
         local values = {}
         for _, column in ipairs(columns) do
            values[#values + 1] = stringify_value(note_value(note, column, source_path))
         end
         rows[#rows + 1] = { note = note, path = tostring(note.path or path), values = values }
      end
   end

   table.sort(rows, function(a, b)
      return a.path < b.path
   end)

   return {
      ast = ast,
      view = view,
      source_path = source_path,
      folder = folder,
      columns = columns,
      rows = rows,
   }
end

local function render_table_buffer(model)
   local Morph = require("morph")
   local h = Morph.h

   local headers = vim.tbl_map(column_label, model.columns)
   local widths = {}
   for col, header in ipairs(headers) do
      local width = display_width(header)
      for _, row in ipairs(model.rows) do
         width = math.max(width, display_width(row.values[col] or ""))
      end

      local configured = configured_column_width(model.view, model.columns[col])
      widths[col] = configured and math.max(display_width(header), configured) or math.min(width, 36)
   end

   local function border(left, middle, right)
      local parts = {}
      for _, width in ipairs(widths) do
         parts[#parts + 1] = string.rep("─", width + 2)
      end
      return h.Comment({}, left .. table.concat(parts, middle) .. right)
   end

   local function open_row(row)
      vim.schedule(function()
         require("obsidian.api").open_note(row.path, "edit")
      end)
   end

   local function row_cells(row, is_header)
      local out = { h.Comment({}, "│ ") }
      for col = 1, #headers do
         local text = is_header and headers[col] or row.values[col]
         text = pad(truncate(text, widths[col]), widths[col])
         if is_header then
            out[#out + 1] = h.Constant({}, text)
         else
            out[#out + 1] = h("text", {
               hl = col == 1 and "Identifier" or "Normal",
               nmap = {
                  ["<CR>"] = function()
                     open_row(row)
                     return ""
                  end,
               },
            }, text)
         end
         out[#out + 1] = h.Comment({}, col == #headers and " │" or " │ ")
      end
      return out
   end

   local function BaseTable()
      local out = { border("┌", "┬", "┐"), "\n", row_cells(nil, true), "\n", border("├", "┼", "┤") }
      for _, row in ipairs(model.rows) do
         out[#out + 1] = "\n"
         out[#out + 1] = row_cells(row, false)
      end
      out[#out + 1] = "\n"
      out[#out + 1] = border("└", "┴", "┘")
      return out
   end

   local function App()
      return {
         h.Title({}, model.view.name or "Table"),
         h.Comment({}, "  " .. #model.rows .. " notes · " .. relative_to_workspace(model.folder, model.source_path)),
         "\n\n",
         #model.rows == 0 and h.Comment({}, "No notes found.") or h(BaseTable, {}, {}),
      }
   end

   vim.cmd.enew()
   local bufnr = vim.api.nvim_get_current_buf()
   local source_name = model.source_path ~= "" and vim.fs.basename(model.source_path) or "base"
   pcall(vim.api.nvim_buf_set_name, bufnr, "Obsidian Base: " .. source_name .. " / " .. (model.view.name or "Table"))
   vim.bo[bufnr].buftype = "nofile"
   vim.bo[bufnr].bufhidden = "wipe"
   vim.bo[bufnr].swapfile = false
   vim.bo[bufnr].filetype = "obsidian-base-table"
   vim.b[bufnr].obsidian_base_source = model.source_path
   vim.b[bufnr].obsidian_base_view = model.view.name

   vim.keymap.set("n", "q", function()
      if #vim.api.nvim_list_wins() > 1 then
         vim.cmd.close()
      else
         vim.cmd.bdelete({ bang = true })
      end
   end, { buffer = bufnr, silent = true })
   Morph.new(bufnr):mount(h(App, {}, {}))
   vim.bo[bufnr].modified = false
end

---Open the current .base table view as a rendered interactive table.
---@param opts { source?: string, source_path?: string, view?: string }|nil
function M.view(opts)
   opts = opts or {}

   local ok, ast_or_err = pcall(M.parse, opts.source or current_buffer_text())
   if not ok then
      notify("failed to parse base: " .. tostring(ast_or_err), vim.log.levels.ERROR)
      return
   end

   local view = select_view(ast_or_err, opts.view)
   if view == nil then
      notify(opts.view and ("view not found: " .. opts.view) or "base has no views", vim.log.levels.ERROR)
      return
   end
   if view.type ~= "table" then
      notify("base view is not a table: " .. tostring(view.name or view.type), vim.log.levels.WARN)
      return
   end

   local ok_model, model_or_err =
      pcall(load_table_model, ast_or_err, view, opts.source_path or vim.api.nvim_buf_get_name(0))
   if not ok_model then
      notify("failed to load base table: " .. tostring(model_or_err), vim.log.levels.ERROR)
      return
   end

   render_table_buffer(model_or_err)
end

---Prompt for a filename and create a note matching the current .base view.
---@param opts { source?: string, view?: string, filename?: string, on_created?: fun(note: obsidian.Note) }|nil
function M.create(opts)
   opts = opts or {}

   local ok, ast_or_err = pcall(M.parse, opts.source or current_buffer_text())
   if not ok then
      notify("failed to parse base: " .. tostring(ast_or_err), vim.log.levels.ERROR)
      return
   end

   local ok_spec, spec_or_err = pcall(M.create_spec, ast_or_err, opts.view)
   if not ok_spec then
      notify(tostring(spec_or_err), vim.log.levels.ERROR)
      return
   end

   local spec = spec_or_err
   if spec.folder == nil or spec.folder == "" then
      notify('base create needs a file.inFolder("...") filter', vim.log.levels.ERROR)
      return
   end

   local function finish(input)
      input = trim(input)
      if input == "" then
         return
      end

      local ok_note, note_or_err = pcall(create_note, input, spec)
      if not ok_note then
         notify("failed to create note: " .. tostring(note_or_err), vim.log.levels.ERROR)
         return
      end

      if opts.on_created then
         opts.on_created(note_or_err)
      end
   end

   if opts.filename ~= nil then
      finish(opts.filename)
      return
   end

   vim.ui.input({ prompt = "New note filename: " }, finish)
end

M.actions = {
   create = M.create,
}

function M.command(data)
   M.actions.create({ view = data.args ~= "" and data.args or nil })
end

return M
