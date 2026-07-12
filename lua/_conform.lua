local pangu = require("pangu")

local function format_special_links(line)
   return line:gsub("【(.-)】%s*<?(https?://[^%s>]+)>?", function(desc, url)
      local suffix = ""
      while url:match("[.,;:!?)%]%}]$") do
         suffix = url:sub(-1) .. suffix
         url = url:sub(1, -2)
      end

      return "[" .. desc .. "](" .. url .. ")" .. suffix
   end)
end

local function auto_url_line(line)
   line = format_special_links(line)

   local parts = {}
   local index = 1

   while true do
      local start_pos, end_pos = line:find("https?://%S+", index)
      if not start_pos then
         table.insert(parts, line:sub(index))
         break
      end

      table.insert(parts, line:sub(index, start_pos - 1))

      local url = line:sub(start_pos, end_pos)
      local char_before = start_pos > 1 and line:sub(start_pos - 1, start_pos - 1) or ""
      local chars_before = start_pos > 2 and line:sub(start_pos - 2, start_pos - 1) or ""

      if char_before == "<" or chars_before == "](" then
         table.insert(parts, url)
      else
         local suffix = ""
         while url:match("[.,;:!?)%]%}]$") do
            suffix = url:sub(-1) .. suffix
            url = url:sub(1, -2)
         end

         table.insert(parts, "<" .. url .. ">" .. suffix)
      end

      index = end_pos + 1
   end

   return table.concat(parts)
end

local function auto_url_lines(lines)
   local formatted = {}
   local in_frontmatter = lines[1] and lines[1]:match("^%-%-%-%s*$") ~= nil

   for index, line in ipairs(lines) do
      if in_frontmatter then
         formatted[index] = line
         if index > 1 and line:match("^%-%-%-%s*$") then
            in_frontmatter = false
         end
      else
         formatted[index] = auto_url_line(line)
      end
   end

   return formatted
end

require("conform").setup({
   format_on_save = function(bufnr)
      local bufname = vim.api.nvim_buf_get_name(bufnr)

      -- List of path patterns to exclude from formatting
      local exclude_patterns = {
         "/Templates/",
         "/docs/Note.md",
      }

      for _, pattern in ipairs(exclude_patterns) do
         if bufname:match(pattern) then
            return -- returning nil skips formatting
         end
      end

      return { timeout_ms = 500, lsp_format = "fallback" }
   end,
   formatters_by_ft = {
      nix = { "alejandra" },
      lua = { "stylua" },
      markdown = { "prettier", "injected", "auto_url", "pangu" },
      quarto = { "prettier" },
      css = { "prettier" },
      qml = { "qmlformat" },
      json = { "jq" },
      python = { "black" },
   },
   formatters = {
      pangu = {
         format = function(_, _, lines, callback)
            callback(nil, pangu.format_lines(lines))
         end,
      },
      auto_url = {
         format = function(_, _, lines, callback)
            callback(nil, auto_url_lines(lines))
         end,
      },
   },
})
