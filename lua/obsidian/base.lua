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
