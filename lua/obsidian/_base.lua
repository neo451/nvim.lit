local M = {}

local cache = require("obsidian.cache")
local cache_note = require("obsidian.cache.note")
local Path = require("obsidian.path")
local util = require("obsidian.util")
local yaml = require("obsidian.yaml")

local table_models = {}
local table_renderers = {}
local auto_render_skip_once = {}
local selection_ns = vim.api.nvim_create_namespace("obsidian-base-selection")
vim.api.nvim_set_hl(0, "ObsidianBaseSelectedRow", { default = true, link = "CursorLine" })
vim.api.nvim_set_hl(0, "ObsidianBaseSelectedCell", { default = true, link = "Visual" })

local function notify(msg, level)
   vim.notify(msg, level or vim.log.levels.INFO, { title = "Obsidian base" })
end

local function trim(s)
   return vim.trim(tostring(s or ""))
end

local function strip_md_suffix(name)
   return Path.new(name).stem
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

local function parse_literal_arg(src)
   src = trim(src)
   local quote = src:sub(1, 1)
   if quote == '"' or quote == "'" then
      return parse_quoted_arg(src, 1)
   elseif src == "true" then
      return true
   elseif src == "false" then
      return false
   elseif tonumber(src) ~= nil then
      return tonumber(src)
   end
   return src
end

---Parse a small Bases expression subset into an AST node.
---Currently supports member calls like `file.inFolder("Folder")` and simple comparisons like `file.folder == "Folder"`.
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

   local property, op, rhs = expr:match("^([%w_]+%.[%w_]+)%s*([=!<>]=?)%s*(.+)$")
   if property ~= nil then
      receiver, property = property:match("^([%w_]+)%.([%w_]+)$")
      return {
         type = "binary",
         receiver = receiver,
         property = property,
         op = op,
         value = parse_literal_arg(rhs),
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

local function parse_scalar(value)
   return yaml.loads("x: " .. trim(value)).x
end

---Parse a .base YAML string into a small AST for actions.
---@param src string
---@return table
function M.parse(src)
   local data = yaml.loads(src)
   if type(data) ~= "table" then
      error("base YAML must contain a mapping")
   end
   local ast = { type = "base", raw = data, views = {} }

   for _, view in ipairs((data and data.views) or {}) do
      ast.views[#ast.views + 1] = parse_view(view)
   end

   return ast
end

local base_source

local function cache_available(silent)
   if cache.is_enabled() then
      return true
   end
   if not silent then
      notify("Bases requires obsidian.nvim cache.enabled = true", vim.log.levels.ERROR)
   end
   return false
end

local function skip_next_auto_render(path)
   if path == nil or path == "" then
      return
   end
   path = vim.fs.normalize(path)
   auto_render_skip_once[path] = true
   vim.defer_fn(function()
      auto_render_skip_once[path] = nil
   end, 1000)
end

---@param src string|nil
---@return string[]
function M.view_names(src)
   if not cache_available(true) then
      return {}
   end
   local source = src or select(1, base_source())
   local ok, ast = pcall(M.parse, source)
   if not ok then
      return {}
   end

   local names = {}
   for _, view in ipairs(ast.views or {}) do
      if view.name ~= nil and view.name ~= "" then
         names[#names + 1] = view.name
      end
   end
   return names
end

local function current_buffer_text()
   return table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
end

local function current_source_path()
   local bufnr = vim.api.nvim_get_current_buf()
   local source = vim.b[bufnr].obsidian_base_source
   if source ~= nil and source ~= "" then
      return source
   end

   local name = vim.api.nvim_buf_get_name(bufnr)
   if name ~= "" then
      return name
   end
end

local function read_file(path)
   local fd, open_err = vim.uv.fs_open(path, "r", 438)
   if fd == nil then
      error(open_err)
   end

   local ok, data_or_err = pcall(function()
      local stat = assert(vim.uv.fs_fstat(fd))
      return assert(vim.uv.fs_read(fd, stat.size, 0))
   end)
   vim.uv.fs_close(fd)
   if not ok then
      error(data_or_err)
   end
   return data_or_err or ""
end

base_source = function(opts)
   opts = opts or {}
   if opts.source ~= nil then
      return opts.source, opts.source_path or current_source_path() or ""
   end

   local source_path = opts.source_path or current_source_path()
   local current_name = vim.api.nvim_buf_get_name(0)
   if vim.bo.filetype ~= "obsidian-base-table" and source_path ~= nil and source_path == current_name then
      return current_buffer_text(), source_path
   end

   if source_path ~= nil and vim.uv.fs_stat(source_path) ~= nil then
      return read_file(source_path), source_path
   end

   return current_buffer_text(), source_path or ""
end

local supported_view_types = { table = true, list = true }

local function view_supported(view)
   return view ~= nil and supported_view_types[view.type] == true
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
      if node.receiver ~= "file" then
         return
      end

      if node.type == "call" and node.method == "inFolder" and spec.folder == nil then
         spec.folder = node.args[1]
      elseif node.type == "binary" and node.property == "folder" and node.op == "==" and spec.folder == nil then
         spec.folder = node.value
      elseif node.type == "call" and node.method == "hasTag" then
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

local function resolve_folder(folder, source_path)
   local path = Path.new(folder)
   if path:is_absolute() then
      return tostring(path)
   end
   return tostring(require("obsidian.api").resolve_workspace_dir(source_path) / path)
end

local function create_note(filename, spec, source_path)
   if filename:find("[/\\]") then
      error("filename must not contain path separators")
   end

   local Note = require("obsidian.note")
   local note = Note.create({
      id = strip_md_suffix(filename),
      dir = resolve_folder(spec.folder, source_path),
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
   local root = require("obsidian.api").resolve_workspace_dir(source_path)
   if folder == nil or folder == "" then
      return tostring(root)
   end

   local path = Path.new(folder)
   return path:is_absolute() and tostring(path) or tostring(root / path)
end

local note_extensions = { md = true, markdown = true, qmd = true }

local function is_cached_note(path)
   local extension = path:match("%.([^./]+)$")
   return extension ~= nil and note_extensions[extension:lower()] == true
end

local function has_all_tags(cache_row, tags)
   local note_tags = {}
   for _, tag in ipairs(cache_row.tags or {}) do
      note_tags[clean_tag(tag):lower()] = true
   end
   for _, tag in ipairs(tags or {}) do
      if not note_tags[clean_tag(tag):lower()] then
         return false
      end
   end
   return true
end

local function view_query(view)
   local query = { folder = nil, folder_exact = false, tags = {} }

   walk_filter(view.filter, function(node)
      if node.receiver ~= "file" then
         return
      end

      if node.type == "call" and node.method == "inFolder" and query.folder == nil then
         query.folder = node.args[1]
      elseif node.type == "binary" and node.property == "folder" and node.op == "==" and query.folder == nil then
         query.folder = node.value
         query.folder_exact = true
      elseif node.type == "call" and node.method == "hasTag" then
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

local function cache_relative(path)
   return cache.notes.rel_path(vim.fs.normalize(path))
end

local function note_value(path, cache_row, column)
   local note_path = Path.new(path)
   if column == "file.name" then
      return cache.notes.basename(path)
   elseif column == "file.path" then
      return cache_relative(path)
   elseif column == "file.folder" then
      local parent = note_path:parent()
      return parent and cache_relative(tostring(parent)) or ""
   elseif column == "file.tags" then
      return cache_row.tags or {}
   elseif type(column) == "string" and column:match("^formula%.") then
      return ""
   end

   local prop = column_property(column)
   if prop == nil then
      return ""
   elseif prop == "id" then
      return note_path.stem
   elseif prop == "aliases" then
      return cache_row.aliases or {}
   elseif prop == "tags" then
      return cache_row.tags or {}
   end

   return cache_row.properties and cache_row.properties[prop] or nil
end

local function is_list(value)
   return type(value) == "table" and vim.islist(value)
end

local function is_date(value)
   if type(value) ~= "string" then
      return false
   end
   local date, rest = value:match("^(%d%d%d%d%-%d%d?%-%d%d?)(.*)$")
   if date == nil or (rest ~= "" and not rest:match("^[T ]%d%d:%d%d[:%d%.Zz+%-]*$")) then
      return false
   end
   return util.parse_date(date, "YYYY-M-D") ~= nil
end

local function supported_property_value(value)
   if value == nil or value == vim.NIL then
      return true
   end
   if type(value) == "string" or type(value) == "number" or type(value) == "boolean" then
      return true
   end
   if not is_list(value) then
      return false
   end
   for _, item in ipairs(value) do
      if type(item) ~= "string" and type(item) ~= "number" and type(item) ~= "boolean" then
         return false
      end
   end
   return true
end

local function parse_typed_scalar(input, expected)
   input = trim(input)
   if type(expected) == "number" then
      local value = tonumber(input)
      if value == nil or value ~= value or value == math.huge or value == -math.huge then
         error("expected a number")
      end
      return value
   elseif type(expected) == "boolean" then
      local value = input:lower()
      if value ~= "true" and value ~= "false" then
         error("expected true or false")
      end
      return value == "true"
   elseif type(expected) == "string" then
      if is_date(expected) and not is_date(input) then
         error("expected a valid date (YYYY-MM-DD)")
      end
      local quote = input:sub(1, 1)
      if (quote == '"' or quote == "'") and input:sub(-1) == quote then
         local parsed = parse_scalar(input)
         if type(parsed) == "string" then
            return parsed
         end
      end
      return input
   end

   if input == "true" then
      return true
   elseif input == "false" then
      return false
   elseif tonumber(input) ~= nil then
      return tonumber(input)
   elseif input:sub(1, 1) == "[" then
      local value = parse_scalar(input)
      if not is_list(value) then
         error("expected a YAML list")
      end
      return value
   end
   return input
end

local function parse_edited_value(input, current, property)
   if type(current) == "table" and not is_list(current) then
      error("mapping values are read-only")
   end

   if is_list(current) or property == "tags" or property == "aliases" then
      local values
      if trim(input) == "" then
         values = {}
      elseif trim(input):sub(1, 1) == "[" then
         values = parse_scalar(input)
         if not is_list(values) then
            error("expected a YAML list")
         end
      else
         values = vim.split(input, ",", { plain = true, trimempty = true })
      end

      local expected = current and current[1]
      for index, value in ipairs(values) do
         if type(value) == "string" then
            values[index] = parse_typed_scalar(value, expected or "")
         elseif expected ~= nil and type(value) ~= type(expected) then
            error("list items must keep their existing type")
         end
      end
      if not supported_property_value(values) then
         error("only lists of strings, numbers, and booleans are editable")
      end
      return values
   end

   local value = parse_typed_scalar(input, current)
   if not supported_property_value(value) then
      error("unsupported property type")
   end
   return value
end

local display_width = util.strdisplaywidth

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

local function sort_column(spec)
   if type(spec) == "string" then
      return spec, "asc"
   end
   if type(spec) ~= "table" then
      return nil, "asc"
   end

   local column = spec.property or spec.column or spec.key or spec.id or spec.name or spec[1]
   local direction = spec.direction or spec.order or spec.dir or spec[2] or "asc"
   if spec.desc == true then
      direction = "desc"
   end
   return column, tostring(direction):lower()
end

local function normalized_sort_specs(sort)
   local specs = {}
   if type(sort) ~= "table" then
      return specs
   end

   if #sort > 0 then
      for _, item in ipairs(sort) do
         local column, direction = sort_column(item)
         if column ~= nil and column ~= "" then
            specs[#specs + 1] = { column = column, direction = direction }
         end
      end
   else
      for column, direction in pairs(sort) do
         specs[#specs + 1] = { column = column, direction = tostring(direction):lower() }
      end
      table.sort(specs, function(a, b)
         return tostring(a.column) < tostring(b.column)
      end)
   end

   return specs
end

local function comparable_value(value)
   if value == nil or value == vim.NIL then
      return nil
   end
   if type(value) == "table" then
      return stringify_value(value):lower()
   end
   if type(value) == "string" then
      local number = tonumber(value)
      return number or value:lower()
   end
   return value
end

local function compare_values(a, b)
   a = comparable_value(a)
   b = comparable_value(b)
   if a == nil and b == nil then
      return 0
   elseif a == nil then
      return 1
   elseif b == nil then
      return -1
   elseif type(a) == "number" and type(b) == "number" then
      return a == b and 0 or (a < b and -1 or 1)
   elseif type(a) == "boolean" and type(b) == "boolean" then
      return a == b and 0 or (not a and -1 or 1)
   end

   a = tostring(a)
   b = tostring(b)
   return a == b and 0 or (a < b and -1 or 1)
end

local function sort_rows(rows, view)
   local specs = normalized_sort_specs(view.sort)
   table.sort(rows, function(a, b)
      for _, spec in ipairs(specs) do
         local cmp =
            compare_values(note_value(a.path, a.cache_row, spec.column), note_value(b.path, b.cache_row, spec.column))
         if cmp ~= 0 then
            local descending = spec.direction == "desc" or spec.direction == "descending"
            return descending and cmp > 0 or cmp < 0
         end
      end
      return a.path < b.path
   end)
end

local function path_matches_folder(path, folder, exact)
   if not exact then
      return util.is_subpath(path, folder)
   end
   local parent = Path.new(path):parent()
   return parent ~= nil and vim.fs.normalize(tostring(parent)) == vim.fs.normalize(folder)
end

local function load_table_model(ast, view, source_path)
   local columns = vim.deepcopy(view.order or {})
   if vim.tbl_isempty(columns) then
      columns = { "file.name" }
   end

   local query = view_query(view)
   local folder = resolve_view_folder(query.folder, source_path)
   local workspace = source_workspace(source_path)
   local cache_root = vim.fs.normalize(tostring(Obsidian.dir))
   if workspace ~= nil and vim.fs.normalize(tostring(workspace.root)) ~= cache_root then
      error("base workspace does not match the active Obsidian cache")
   elseif not util.is_subpath(folder, cache_root) then
      error("base folder is outside the active Obsidian cache: " .. folder)
   end
   local stat = vim.uv.fs_stat(folder)
   if stat == nil or stat.type ~= "directory" then
      error("base folder not found: " .. folder)
   end

   local rows = {}
   for path, cache_row in pairs(cache.notes.all()) do
      path = vim.fs.normalize(path)
      if
         is_cached_note(path)
         and path_matches_folder(path, folder, query.folder_exact)
         and has_all_tags(cache_row, query.tags)
      then
         local values = {}
         local raw_values = {}
         for _, column in ipairs(columns) do
            local value = note_value(path, cache_row, column)
            raw_values[#raw_values + 1] = value == nil and vim.NIL or value
            values[#values + 1] = stringify_value(value)
         end
         rows[#rows + 1] = {
            cache_row = cache_row,
            path = path,
            values = values,
            raw_values = raw_values,
         }
      end
   end

   sort_rows(rows, view)

   return {
      ast = ast,
      view = view,
      source_path = source_path,
      folder = folder,
      columns = columns,
      rows = rows,
   }
end

local function selected_row(bufnr)
   local model = table_models[bufnr]
   if model == nil then
      return nil, nil
   end
   local index = tonumber(vim.b[bufnr].obsidian_base_selected_row) or 1
   return model.rows[index], model
end

local function set_selection(bufnr, row_index, column_index, move_cursor)
   local model = table_models[bufnr]
   if model == nil then
      return
   end

   local row_count, column_count = #model.rows, #model.columns
   row_index = row_count == 0 and 0 or math.max(1, math.min(tonumber(row_index) or 1, row_count))
   column_index = column_count == 0 and 0 or math.max(1, math.min(tonumber(column_index) or 1, column_count))
   vim.b[bufnr].obsidian_base_selected_row = row_index
   vim.b[bufnr].obsidian_base_selected_col = column_index

   vim.api.nvim_buf_clear_namespace(bufnr, selection_ns, 0, -1)
   local row = model.rows[row_index]
   if row == nil or row.line == nil then
      return
   end

   vim.api.nvim_buf_set_extmark(bufnr, selection_ns, row.line - 1, 0, {
      line_hl_group = "ObsidianBaseSelectedRow",
      priority = 100,
   })
   local range = row.cell_ranges and row.cell_ranges[column_index]
   if range ~= nil then
      vim.api.nvim_buf_set_extmark(bufnr, selection_ns, row.line - 1, range[1], {
         end_row = row.line - 1,
         end_col = range[2],
         hl_group = "ObsidianBaseSelectedCell",
         priority = 200,
      })
   end

   if move_cursor then
      local winid = vim.fn.bufwinid(bufnr)
      if winid ~= -1 and vim.api.nvim_win_is_valid(winid) then
         vim.api.nvim_win_set_cursor(winid, { row.line, range and range[1] or 0 })
      end
   end
end

function M.move_selection(row_delta, column_delta, edge)
   local bufnr = vim.api.nvim_get_current_buf()
   local model = table_models[bufnr]
   if model == nil or #model.rows == 0 then
      return
   end

   local row = tonumber(vim.b[bufnr].obsidian_base_selected_row) or 1
   local column = tonumber(vim.b[bufnr].obsidian_base_selected_col) or 1
   if edge == "first" then
      row = 1
   elseif edge == "last" then
      row = #model.rows
   else
      row = row + (row_delta or 0)
      column = column + (column_delta or 0)
   end
   set_selection(bufnr, row, column, true)
end

function M.row_action(command)
   local bufnr = vim.api.nvim_get_current_buf()
   local row = selected_row(bufnr)
   if row == nil then
      notify("base has no selected row", vim.log.levels.WARN)
      return
   end

   vim.schedule(function()
      if command == nil or command == "edit" then
         require("obsidian.api").open_note(row.path, "edit")
      else
         vim.cmd(command .. " " .. vim.fn.fnameescape(row.path))
      end
   end)
end

local function normal_window_count()
   local count = 0
   for _, winid in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      if vim.api.nvim_win_get_config(winid).relative == "" then
         count = count + 1
      end
   end
   return count
end

local function close_table_buffer()
   local bufnr = vim.api.nvim_get_current_buf()
   local model = table_models[bufnr]
   if model ~= nil then
      skip_next_auto_render(model.source_path)
   end

   if normal_window_count() > 1 then
      vim.api.nvim_win_close(0, true)
      return
   end

   local alt = vim.fn.bufnr("#")
   local switched = false
   if alt > 0 and alt ~= bufnr and vim.api.nvim_buf_is_valid(alt) then
      switched = pcall(vim.api.nvim_set_current_buf, alt)
   end
   if not switched then
      vim.cmd.enew()
   end

   if vim.api.nvim_buf_is_valid(bufnr) then
      pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
   end
end

function M.yank_row(link)
   local row = selected_row(vim.api.nvim_get_current_buf())
   if row == nil then
      notify("base has no selected row", vim.log.levels.WARN)
      return
   end

   local text = row.path
   if link then
      text = "[[" .. Path.new(row.path).stem .. "]]"
   end
   vim.fn.setreg(vim.v.register, text)
   notify("yanked " .. text)
end

function M.edit_cell()
   local bufnr = vim.api.nvim_get_current_buf()
   local row, model = selected_row(bufnr)
   local column_index = tonumber(vim.b[bufnr].obsidian_base_selected_col) or 1
   local column = model and model.columns[column_index]
   local property = column_property(column)
   if row == nil then
      notify("base has no selected row", vim.log.levels.WARN)
      return
   elseif property == nil then
      notify("computed and file columns are read-only", vim.log.levels.WARN)
      return
   end

   local current = row.raw_values[column_index]
   if current == vim.NIL then
      current = nil
   end
   if not supported_property_value(current) then
      notify("this property type is read-only", vim.log.levels.WARN)
      return
   end

   vim.ui.input({
      prompt = "Edit " .. property .. ": ",
      default = stringify_value(current),
   }, function(input)
      if input == nil then
         return
      end

      local ok_value, value_or_err = pcall(parse_edited_value, input, current, property)
      if not ok_value then
         notify("invalid value: " .. tostring(value_or_err), vim.log.levels.ERROR)
         return
      end

      local normalized_path = vim.fs.normalize(row.path)
      for _, note_bufnr in ipairs(vim.api.nvim_list_bufs()) do
         if
            vim.api.nvim_buf_is_loaded(note_bufnr)
            and vim.fs.normalize(vim.api.nvim_buf_get_name(note_bufnr)) == normalized_path
            and vim.bo[note_bufnr].modified
         then
            notify("save or discard changes in the note before editing its property", vim.log.levels.ERROR)
            return
         end
      end

      local ok_write, write_err = pcall(function()
         local note = require("obsidian.note").from_file(row.path)
         if property == "id" then
            note.id = value_or_err
         elseif property == "aliases" then
            note.aliases = value_or_err
         elseif property == "tags" then
            note.tags = value_or_err
         else
            note:add_field(property, value_or_err)
         end
         note:write()

         -- Keep this refresh synchronous instead of waiting for the cache's file watcher.
         local workspace = source_workspace(model.source_path)
         local cached = cache_note.build(row.path, workspace and tostring(workspace.root) or "")
         if cached ~= nil then
            cached.path = row.path
            cache.notes.upsert(cached)
         end
      end)
      if not ok_write then
         notify("failed to update property: " .. tostring(write_err), vim.log.levels.ERROR)
         return
      end

      if vim.api.nvim_buf_is_valid(bufnr) then
         M.view({ source_path = model.source_path, view = model.view.name, bufnr = bufnr })
      end
      notify("updated " .. property)
   end)
end

local function setup_table_keymaps(bufnr)
   local map = function(lhs, rhs, desc)
      vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
   end

   map("j", function()
      M.move_selection(vim.v.count1, 0)
   end, "Select next base row")
   map("k", function()
      M.move_selection(-vim.v.count1, 0)
   end, "Select previous base row")
   map("h", function()
      M.move_selection(0, -vim.v.count1)
   end, "Select previous base column")
   map("l", function()
      M.move_selection(0, vim.v.count1)
   end, "Select next base column")
   map("gg", function()
      M.move_selection(0, 0, "first")
   end, "Select first base row")
   map("G", function()
      M.move_selection(0, 0, "last")
   end, "Select last base row")
   map("<CR>", function()
      M.row_action()
   end, "Open selected base note")
   map("o", function()
      M.row_action()
   end, "Open selected base note")
   map("v", function()
      M.row_action("vsplit")
   end, "Open selected base note in vertical split")
   map("s", function()
      M.row_action("split")
   end, "Open selected base note in split")
   map("t", function()
      M.row_action("tabedit")
   end, "Open selected base note in tab")
   map("y", function()
      M.yank_row(false)
   end, "Yank selected base note path")
   map("Y", function()
      M.yank_row(true)
   end, "Yank selected base note link")
   map("e", M.edit_cell, "Edit selected base property")
   map("i", M.edit_cell, "Edit selected base property")
   map("E", M.open_source, "Edit base source")
   map("q", close_table_buffer, "Close base table")
   map("r", M.refresh, "Refresh base table")
   local create_for_current_view = function()
      local current = table_models[vim.api.nvim_get_current_buf()]
      if current ~= nil then
         M.create({ source_path = current.source_path, view = current.view.name })
      end
   end
   map("c", create_for_current_view, "Create note for base view")
   map("a", create_for_current_view, "Create note for base view")
   map("?", function()
      notify(
         "keys: j/k rows, h/l columns, gg/G first/last, e/i edit property, <CR>/o open, v/s/t split, y/Y yank, c/a create, r refresh, E source, q close"
      )
   end, "Base table help")
end

local function list_marker(view, index)
   local marker = tostring(view.raw.markers or view.raw.marker or "bullet"):lower()
   if marker == "number" or marker == "numbers" or marker == "ordered" then
      return tostring(index) .. ". "
   elseif marker == "none" or marker == "no" or marker == "false" then
      return ""
   end
   return "• "
end

local function list_separator(view)
   local separator = view.raw.separator or view.raw.separators or view.raw.propertySeparator or ","
   separator = tostring(separator)
   if separator == "" then
      return " "
   elseif separator:match("%s$") then
      return separator
   else
      return separator .. " "
   end
end

local function render_table_buffer(model, opts)
   opts = opts or {}

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

   local function row_cells(row, is_header)
      local out = { h.Comment({}, "│ ") }
      local byte_col = #"│ "
      if row ~= nil then
         row.cell_ranges = {}
      end
      for col = 1, #headers do
         local text = is_header and headers[col] or row.values[col]
         text = pad(truncate(text, widths[col]), widths[col])
         if row ~= nil then
            row.cell_ranges[col] = { byte_col, byte_col + #text }
         end
         out[#out + 1] = h("text", { hl = is_header and "Constant" or (col == 1 and "Identifier" or "Normal") }, text)
         byte_col = byte_col + #text
         local separator = col == #headers and " │" or " │ "
         out[#out + 1] = h.Comment({}, separator)
         byte_col = byte_col + #separator
      end
      return out
   end

   local function BaseTable()
      model.line_to_row = {}
      local out = { border("┌", "┬", "┐"), "\n", row_cells(nil, true), "\n", border("├", "┼", "┤") }
      for index, row in ipairs(model.rows) do
         row.line = index + 5
         row.end_line = row.line
         model.line_to_row[row.line] = index
         out[#out + 1] = "\n"
         out[#out + 1] = row_cells(row, false)
      end
      out[#out + 1] = "\n"
      out[#out + 1] = border("└", "┴", "┘")
      return out
   end

   local function inline_list_row(row, row_index, line)
      local marker = list_marker(model.view, row_index)
      local out = { h.Comment({}, marker) }
      local byte_col = #marker
      row.cell_ranges = {}

      local primary = row.values[1] or ""
      row.cell_ranges[1] = { byte_col, byte_col + #primary }
      out[#out + 1] = h("text", { hl = "Identifier" }, primary)
      byte_col = byte_col + #primary

      local separator = list_separator(model.view)
      for col = 2, #model.columns do
         local value = row.values[col]
         if value ~= nil and value ~= "" then
            out[#out + 1] = h.Comment({}, separator)
            byte_col = byte_col + #separator
            local text = column_label(model.columns[col]) .. ": " .. value
            row.cell_ranges[col] = { byte_col, byte_col + #text }
            out[#out + 1] = h("text", { hl = "Normal" }, text)
            byte_col = byte_col + #text
         end
      end

      row.line = line
      row.end_line = line
      model.line_to_row[line] = row_index
      return out
   end

   local function indented_list_row(row, row_index, line)
      local marker = list_marker(model.view, row_index)
      local primary = row.values[1] or ""
      row.line = line
      row.end_line = line
      row.cell_ranges = { { #marker, #marker + #primary } }
      model.line_to_row[line] = row_index

      local out = { h.Comment({}, marker), h("text", { hl = "Identifier" }, primary) }
      for col = 2, #model.columns do
         local value = row.values[col]
         if value ~= nil and value ~= "" then
            local text = column_label(model.columns[col]) .. ": " .. value
            out[#out + 1] = "\n"
            out[#out + 1] = h.Comment({}, "  • ")
            out[#out + 1] = h("text", { hl = "Constant" }, text)
            line = line + 1
            row.end_line = line
            model.line_to_row[line] = row_index
         end
      end
      return out, line
   end

   local function BaseList()
      model.line_to_row = {}
      local out = {}
      local line = 3
      local indent_properties = model.view.raw.indentProperties == true
      for index, row in ipairs(model.rows) do
         if index > 1 then
            out[#out + 1] = "\n"
            line = line + 1
         end
         if indent_properties then
            local rendered
            rendered, line = indented_list_row(row, index, line)
            out[#out + 1] = rendered
         else
            out[#out + 1] = inline_list_row(row, index, line)
         end
      end
      return out
   end

   local function BaseBody()
      if #model.rows == 0 then
         return h.Comment({}, "No notes found.")
      elseif model.view.type == "list" then
         return h(BaseList, {}, {})
      else
         return h(BaseTable, {}, {})
      end
   end

   local function App()
      return {
         h.Title({}, model.view.name or (model.view.type == "list" and "List" or "Table")),
         h.Comment({}, "  " .. #model.rows .. " notes · " .. cache_relative(model.folder)),
         "\n\n",
         h(BaseBody, {}, {}),
      }
   end

   local bufnr = opts.bufnr
   if bufnr ~= nil and vim.api.nvim_buf_is_valid(bufnr) then
      vim.api.nvim_set_current_buf(bufnr)
   else
      bufnr = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_set_current_buf(bufnr)
   end

   local previous = table_models[bufnr]
   local previous_row = tonumber(vim.b[bufnr].obsidian_base_selected_row) or 1
   local selected_path = previous and previous.rows[previous_row] and previous.rows[previous_row].path
   local selected_column = tonumber(vim.b[bufnr].obsidian_base_selected_col) or 1
   local selected_index = 1
   if selected_path ~= nil then
      for index, row in ipairs(model.rows) do
         if row.path == selected_path then
            selected_index = index
            break
         end
      end
   end
   table_models[bufnr] = model

   local source_name = model.source_path ~= "" and vim.fs.basename(model.source_path) or "base"
   pcall(vim.api.nvim_buf_set_name, bufnr, "Obsidian Base: " .. source_name .. " / " .. (model.view.name or "Table"))
   vim.bo[bufnr].buftype = "nofile"
   vim.bo[bufnr].bufhidden = "wipe"
   vim.bo[bufnr].swapfile = false
   vim.bo[bufnr].filetype = "obsidian-base-table"
   vim.bo[bufnr].modifiable = true
   vim.b[bufnr].obsidian_base_source = model.source_path
   vim.b[bufnr].obsidian_base_view = model.view.name
   if previous == nil or previous.view.name ~= model.view.name then
      vim.b[bufnr].obsidian_base_runtime_filter = ""
      vim.b[bufnr].obsidian_base_runtime_sort = normalized_sort_specs(model.view.sort)
   end

   local buffer_model = { source_path = model.source_path, view = model.view.name, columns = model.columns, rows = {} }
   for _, row in ipairs(model.rows) do
      buffer_model.rows[#buffer_model.rows + 1] = { path = row.path, values = row.values }
   end
   vim.b[bufnr].obsidian_base_model = buffer_model

   setup_table_keymaps(bufnr)
   if table_renderers[bufnr] == nil then
      table_renderers[bufnr] = Morph.new(bufnr)
      vim.api.nvim_create_autocmd({ "BufWipeout", "BufDelete" }, {
         buffer = bufnr,
         once = true,
         callback = function()
            table_models[bufnr] = nil
            table_renderers[bufnr] = nil
         end,
      })
      vim.api.nvim_create_autocmd("CursorMoved", {
         buffer = bufnr,
         callback = function()
            local current = table_models[bufnr]
            if current == nil then
               return
            end
            local cursor = vim.api.nvim_win_get_cursor(0)
            local index = current.line_to_row and current.line_to_row[cursor[1]] or (cursor[1] - 5)
            local row = current.rows[index]
            if row == nil then
               return
            end
            local column = tonumber(vim.b[bufnr].obsidian_base_selected_col) or 1
            if cursor[1] == row.line then
               for candidate, range in ipairs(row.cell_ranges or {}) do
                  if cursor[2] >= range[1] and cursor[2] <= range[2] then
                     column = candidate
                     break
                  end
               end
            end
            set_selection(bufnr, index, column, false)
         end,
      })
   end

   local function draw()
      if not vim.api.nvim_buf_is_valid(bufnr) then
         return
      end
      vim.bo[bufnr].modifiable = true
      table_renderers[bufnr]:render(h(App, {}, {}))
      vim.bo[bufnr].modifiable = false
      vim.bo[bufnr].modified = false
      set_selection(bufnr, selected_index, selected_column, true)
   end

   if vim.v.vim_did_enter == 0 then
      vim.api.nvim_create_autocmd("VimEnter", { once = true, callback = draw })
   else
      draw()
   end
end

---Open the current .base view as a rendered interactive buffer.
---@param opts { source?: string, source_path?: string, view?: string }|nil
function M.view(opts)
   opts = opts or {}
   if not cache_available() then
      return
   end

   local source, source_path = base_source(opts)
   local ok, ast_or_err = pcall(M.parse, source)
   if not ok then
      notify("failed to parse base: " .. tostring(ast_or_err), vim.log.levels.ERROR)
      return
   end

   local view = select_view(ast_or_err, opts.view)
   if view == nil then
      notify(opts.view and ("view not found: " .. opts.view) or "base has no views", vim.log.levels.ERROR)
      return
   end
   if not view_supported(view) then
      notify("base view is not supported: " .. tostring(view.name or view.type), vim.log.levels.WARN)
      return
   end

   local function load_from_cache()
      local ok_model, model_or_err = pcall(load_table_model, ast_or_err, view, source_path)
      if not ok_model then
         notify("failed to load base table: " .. tostring(model_or_err), vim.log.levels.ERROR)
         return
      end
      render_table_buffer(model_or_err, { bufnr = opts.bufnr })
   end

   if cache.is_ready() then
      load_from_cache()
   else
      notify("waiting for the Obsidian cache to finish indexing")
      cache.when_ready(load_from_cache)
   end
end

---Refresh the current rendered base table in-place when possible.
---@param opts { source_path?: string, view?: string }|nil
function M.refresh(opts)
   opts = opts or {}
   local bufnr = vim.api.nvim_get_current_buf()
   M.view({
      source_path = opts.source_path or vim.b[bufnr].obsidian_base_source or current_source_path(),
      view = opts.view or vim.b[bufnr].obsidian_base_view,
      bufnr = vim.bo[bufnr].filetype == "obsidian-base-table" and bufnr or nil,
   })
end

---Open the .base YAML source for the current rendered table.
function M.open_source()
   if not cache_available() then
      return
   end
   local source = vim.b[vim.api.nvim_get_current_buf()].obsidian_base_source or current_source_path()
   if source == nil or source == "" or vim.uv.fs_stat(source) == nil then
      notify("base source file not found", vim.log.levels.ERROR)
      return
   end
   skip_next_auto_render(source)
   vim.cmd.edit(vim.fn.fnameescape(source))
end

---Prompt for a view and open it.
---@param opts { source?: string, source_path?: string }|nil
function M.pick_view(opts)
   opts = opts or {}
   if not cache_available() then
      return
   end
   local source, source_path = base_source(opts)
   local ok, ast = pcall(M.parse, source)
   if not ok then
      notify("failed to parse base: " .. tostring(ast), vim.log.levels.ERROR)
      return
   end

   if vim.tbl_isempty(ast.views) then
      notify("base has no views", vim.log.levels.ERROR)
      return
   end

   vim.ui.select(ast.views, {
      prompt = "Base view",
      format_item = function(view)
         return (view.name or "<unnamed>") .. "  " .. (view.type or "")
      end,
   }, function(view)
      if view == nil then
         return
      end
      local bufnr = vim.api.nvim_get_current_buf()
      M.view({
         source = source,
         source_path = source_path,
         view = view.name,
         bufnr = vim.bo[bufnr].filetype == "obsidian-base-table" and bufnr or nil,
      })
   end)
end

local function cycle_view(delta)
   if not cache_available() then
      return
   end
   local source, source_path = base_source()
   local ok, ast = pcall(M.parse, source)
   if not ok then
      notify("failed to parse base: " .. tostring(ast), vim.log.levels.ERROR)
      return
   end
   if vim.tbl_isempty(ast.views) then
      notify("base has no views", vim.log.levels.ERROR)
      return
   end

   local current = vim.b[vim.api.nvim_get_current_buf()].obsidian_base_view
   local index = 1
   for i, view in ipairs(ast.views) do
      if view.name == current then
         index = i
         break
      end
   end

   index = ((index - 1 + delta) % #ast.views) + 1
   local bufnr = vim.api.nvim_get_current_buf()
   M.view({
      source = source,
      source_path = source_path,
      view = ast.views[index].name,
      bufnr = vim.bo[bufnr].filetype == "obsidian-base-table" and bufnr or nil,
   })
end

function M.next_view()
   cycle_view(1)
end

function M.prev_view()
   cycle_view(-1)
end

---Prompt for a filename and create a note matching the current .base view.
---@param opts { source?: string, source_path?: string, view?: string, filename?: string, on_created?: fun(note: obsidian.Note) }|nil
function M.create(opts)
   opts = opts or {}
   if not cache_available() then
      return
   end

   local source, source_path = base_source(opts)
   local ok, ast_or_err = pcall(M.parse, source)
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

      local ok_note, note_or_err = pcall(create_note, input, spec, source_path)
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

local auto_render_group

local function maybe_auto_render(bufnr)
   if not vim.api.nvim_buf_is_valid(bufnr) or vim.api.nvim_get_current_buf() ~= bufnr then
      return
   end
   if not cache_available(true) or vim.bo[bufnr].buftype ~= "" or vim.bo[bufnr].modified then
      return
   end

   local source_path = vim.api.nvim_buf_get_name(bufnr)
   if source_path == "" or not source_path:match("%.base$") then
      return
   end
   source_path = vim.fs.normalize(source_path)

   if auto_render_skip_once[source_path] then
      auto_render_skip_once[source_path] = nil
      return
   end

   local ok_workspace, workspace = pcall(require("obsidian.api").find_workspace, source_path)
   if not ok_workspace or workspace == nil then
      return
   end

   local source = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
   local ok, ast = pcall(M.parse, source)
   if not ok or not ast.views or not view_supported(ast.views[1]) then
      return
   end

   M.view({ source = source, source_path = source_path, view = ast.views[1].name })
end

function M.setup_autocmd()
   if auto_render_group ~= nil then
      return
   end
   auto_render_group = vim.api.nvim_create_augroup("obsidian-base-auto-render", { clear = true })
   vim.api.nvim_create_autocmd("BufEnter", {
      group = auto_render_group,
      callback = function(ev)
         vim.schedule(function()
            maybe_auto_render(ev.buf)
         end)
      end,
   })
end

M.actions = {
   create = M.create,
   view = M.view,
   refresh = M.refresh,
   source = M.open_source,
   views = M.pick_view,
   next = M.next_view,
   prev = M.prev_view,
}

return M
