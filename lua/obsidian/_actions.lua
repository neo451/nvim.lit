local obsidian = require("obsidian")
local log = obsidian.log

local function capture_to_daily(text, open)
   -- TODO: select date
   -- TODO: create date note
   -- TODO: get headings note api

   text = text or obsidian.api.input("Capture")

   local daily = require("obsidian.daily")
   local path = daily.daily_note_path(os.time())
   local today_note = obsidian.Note.from_file(path)

   vim.ui.select({
      "Tasks",
      "TIL",
      "Entries",
      "Wins",
      "Gratitudes",
   }, {}, function(choice)
      if not choice then
         log.info("Aborted")
         return
      end
      today_note:insert_text("- " .. text, {
         section = {
            header = choice,
            level = 2,
            on_missing = "create",
         },
      })
      if open then
         today_note:open({ sync = true })
      end
   end)
end

local function new_spinner(bufnr, row, col)
   local id = string.format("extmark-spinner-%d-%d-%d", bufnr, row, col)
   require("spinner").config(id, {
      kind = "extmark",
      bufnr = bufnr, -- must be provided
      row = row, -- must be provided, which line, 0-based
      col = col, -- must be provided, which col, 0-based

      ns = vim.api.nvim_create_namespace("ext-spinner"), -- namespace, optional
      hl_group = "Spinner", -- hl_group for text, optional
   })
   return id
end

-- TODO: handle the clipboard image, and make a floating window to edit the text before putting

local function run_ollama(path, prompt)
   local spinner = require("spinner")
   local cmds = { "ollama", "run", "qwen3-vl:2b", path, prompt, "--hidethinking" }
   -- local cmds = { "tesseract", path, "stdout", "-l", "chi_sim" }

   local row, col = unpack(vim.api.nvim_win_get_cursor(0))
   row = row - 1 -- 0-based
   local id = new_spinner(vim.api.nvim_get_current_buf(), row, col)
   spinner.start(id)

   vim.system(
      cmds,
      {},
      vim.schedule_wrap(function(out)
         if out.code ~= 0 then
            log.err("Failed to process image:", out.stderr)
            return
         end
         spinner.stop(id)
         vim.fn.setreg('"', out.stdout)
         log.info('output saved to register "')
      end)
   )
end

local function parse_obsidian_footnote_def(line)
   local label, stop = line:match("^%s*%[%^([^%]]+)%]:()")
   return label, stop
end

local function collect_footnote_labels(lines)
   local labels = {}
   for _, line in ipairs(lines) do
      local label = line:match("^%s*%[(%d+)%]:") or line:match("^%s*%[%^([^%]]+)%]:")
      if label and label ~= "" then
         labels[label] = true
      end
   end
   return labels
end

local function replace_markdown_footnote_refs(line, labels)
   local out = {}
   local i = 1
   local count = 0

   while i <= #line do
      local rest = line:sub(i)
      local prev = line:sub(i - 1, i - 1)
      local text, label, stop = rest:match("^%((%b[])%[(%d+)%]%)()")
      local next_char = stop and rest:sub(stop, stop) or ""
      if label and labels[label] and prev ~= "!" and prev ~= "[" and next_char ~= "]" and not text:match("^%[%^") then
         out[#out + 1] = "[^" .. label .. "]"
         i = i + stop - 1
         count = count + 1
      else
         label, stop = rest:match("^%(%[(%d+)%]%)()")
         if label and labels[label] then
            out[#out + 1] = "[^" .. label .. "]"
            i = i + stop - 1
            count = count + 1
         else
            text, label, stop = rest:match("^(%b[])%[(%d+)%]()")
            next_char = stop and rest:sub(stop, stop) or ""
            if label and labels[label] and prev ~= "!" and prev ~= "[" and next_char ~= "]" and not text:match("^%[%^") then
               out[#out + 1] = "[^" .. label .. "]"
               i = i + stop - 1
               count = count + 1
            else
               label, stop = rest:match("^%[(%d+)%]()")
               next_char = stop and rest:sub(stop, stop) or ""
               if label and labels[label] and prev ~= "!" and prev ~= "[" and next_char ~= "(" and next_char ~= "[" and next_char ~= ":" and next_char ~= "]" then
                  out[#out + 1] = "[^" .. label .. "]"
                  i = i + stop - 1
                  count = count + 1
               else
                  out[#out + 1] = line:sub(i, i)
                  i = i + 1
               end
            end
         end
      end
   end

   return table.concat(out), count
end

local function convert_markdown_footnotes(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local labels = collect_footnote_labels(lines)
   local converted_refs = 0
   local converted_defs = 0

   for i, line in ipairs(lines) do
      local def_count
      line, def_count = line:gsub("^(%s*)%[(%d+)%](:)", "%1[^%2]%3")
      converted_defs = converted_defs + def_count

      local ref_count
      line, ref_count = replace_markdown_footnote_refs(line, labels)
      converted_refs = converted_refs + ref_count

      if line ~= lines[i] then
         vim.api.nvim_buf_set_lines(bufnr, i - 1, i, false, { line })
      end
   end

   return converted_refs, converted_defs
end

local function scan_obsidian_footnote_refs(line, start_col)
   local refs = {}
   local search_from = start_col or 1

   while true do
      local from, to, label = line:find("%[%^([^%]]+)%]", search_from)
      if not from then
         break
      end
      if label ~= "" then
         refs[#refs + 1] = { label = label, col = from }
      end
      search_from = to + 1
   end

   return refs
end

local function collect_footnote_issues(bufnr)
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local defs = {}
   local refs = {}

   for lnum, line in ipairs(lines) do
      local def_label, def_stop = parse_obsidian_footnote_def(line)
      if def_label then
         defs[def_label] = defs[def_label] or {}
         defs[def_label][#defs[def_label] + 1] = {
            label = def_label,
            lnum = lnum,
            col = line:find("[^", 1, true) or 1,
            text = line,
         }
      end

      for _, ref in ipairs(scan_obsidian_footnote_refs(line, def_stop or 1)) do
         refs[ref.label] = refs[ref.label] or {}
         refs[ref.label][#refs[ref.label] + 1] = {
            label = ref.label,
            lnum = lnum,
            col = ref.col,
            text = line,
         }
      end
   end

   local issues = {}
   for label, locs in pairs(defs) do
      if not refs[label] then
         for _, loc in ipairs(locs) do
            loc.kind = "orphan_def"
            loc.message = "Footnote entry [^" .. label .. "] has no reference"
            issues[#issues + 1] = loc
         end
      end
   end
   for label, locs in pairs(refs) do
      if not defs[label] then
         for _, loc in ipairs(locs) do
            loc.kind = "dangling_ref"
            loc.message = "Footnote ref [^" .. label .. "] has no entry"
            issues[#issues + 1] = loc
         end
      end
   end

   table.sort(issues, function(a, b)
      if a.lnum ~= b.lnum then
         return a.lnum < b.lnum
      end
      return a.col < b.col
   end)

   return issues
end

local function load_footnote_issues_to_quickfix(bufnr, issues)
   local items = {}
   for _, issue in ipairs(issues) do
      items[#items + 1] = {
         bufnr = bufnr,
         lnum = issue.lnum,
         col = issue.col,
         type = "W",
         text = issue.message,
      }
   end

   vim.fn.setqflist({}, "r", { title = "Obsidian footnote issues", items = items })
   vim.cmd.copen()
end

local function remove_dangling_footnote_refs(line, labels)
   local out = {}
   local i = 1
   local count = 0

   while i <= #line do
      local from, to, label = line:find("%[%^([^%]]+)%]", i)
      if not from then
         out[#out + 1] = line:sub(i)
         break
      end

      out[#out + 1] = line:sub(i, from - 1)
      if labels[label] then
         count = count + 1
      else
         out[#out + 1] = line:sub(from, to)
      end
      i = to + 1
   end

   return table.concat(out), count
end

local function remove_footnote_issues(bufnr, issues)
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local remove_lines = {}
   local dangling_labels = {}
   local removed_defs = 0
   local removed_refs = 0

   for _, issue in ipairs(issues) do
      if issue.kind == "orphan_def" then
         remove_lines[issue.lnum] = true
      elseif issue.kind == "dangling_ref" then
         dangling_labels[issue.label] = true
      end
   end

   local new_lines = {}
   for lnum, line in ipairs(lines) do
      if remove_lines[lnum] then
         removed_defs = removed_defs + 1
      else
         local ref_count
         line, ref_count = remove_dangling_footnote_refs(line, dangling_labels)
         removed_refs = removed_refs + ref_count
         new_lines[#new_lines + 1] = line
      end
   end

   vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, new_lines)
   return removed_refs, removed_defs
end

local function cleanup_footnotes(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local converted_refs, converted_defs = convert_markdown_footnotes(bufnr)
   local issues = collect_footnote_issues(bufnr)

   if #issues == 0 then
      if converted_refs + converted_defs == 0 then
         log.info("No footnote issues found")
      else
         log.info(string.format("Converted %d Markdown footnote refs and %d definitions; no issues found", converted_refs, converted_defs))
      end
      return
   end

   local choice = require("obsidian.api").confirm(
      string.format("Found %d footnote issue(s).", #issues),
      "&Remove invalid\n&Quickfix\n&Cancel"
   )

   if choice == "Remove invalid" then
      local removed_refs, removed_defs = remove_footnote_issues(bufnr, issues)
      log.info(
         string.format(
            "Converted %d Markdown refs and %d definitions; removed %d invalid refs and %d orphan entries",
            converted_refs,
            converted_defs,
            removed_refs,
            removed_defs
         )
      )
   elseif choice == "Quickfix" then
      load_footnote_issues_to_quickfix(bufnr, issues)
   else
      log.info("Footnote cleanup aborted")
   end
end

local function trim(text)
   return text:match("^%s*(.-)%s*$")
end

local function split_markdown_table_row(line)
   local text = trim(line)
   if text:sub(1, 1) == "|" then
      text = text:sub(2)
   end
   if text:sub(-1) == "|" then
      text = text:sub(1, -2)
   end

   local cells = {}
   local cell = {}
   local escaped = false
   for i = 1, #text do
      local char = text:sub(i, i)
      if char == "|" and not escaped then
         cells[#cells + 1] = trim(table.concat(cell))
         cell = {}
      else
         cell[#cell + 1] = char
      end

      if char == "\\" and not escaped then
         escaped = true
      else
         escaped = false
      end
   end
   cells[#cells + 1] = trim(table.concat(cell))

   return cells
end

local function is_markdown_table_separator(line)
   local cells = split_markdown_table_row(line)
   if #cells == 0 then
      return false
   end

   for _, cell in ipairs(cells) do
      if not cell:match("^:?-+:?$") then
         return false
      end
   end
   return true
end

local function is_markdown_table_line(line)
   return line:find("|", 1, true) ~= nil
end

local function find_markdown_table_bounds(bufnr)
   local cursor = vim.api.nvim_win_get_cursor(0)[1]
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   if not is_markdown_table_line(lines[cursor] or "") then
      return nil
   end

   local start = cursor
   while start > 1 and is_markdown_table_line(lines[start - 1]) do
      start = start - 1
   end

   local finish = cursor
   while finish < #lines and is_markdown_table_line(lines[finish + 1]) do
      finish = finish + 1
   end

   local separator
   for lnum = start, finish do
      if is_markdown_table_separator(lines[lnum]) then
         separator = lnum
         break
      end
   end

   if not separator then
      return nil
   end

   return start, finish, separator, lines
end

local function markdown_table_to_list(bufnr, ordered, primary_index)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local start, finish, separator, lines = find_markdown_table_bounds(bufnr)
   if not start then
      log.err("Cursor is not in a Markdown table")
      return
   end

   local row_lines = {}
   for lnum = separator + 1, finish do
      if not is_markdown_table_separator(lines[lnum]) then
         row_lines[#row_lines + 1] = lines[lnum]
      end
   end

   if #row_lines == 0 then
      log.err("Markdown table has no data rows")
      return
   end

   local columns = split_markdown_table_row(row_lines[1])
   if primary_index < 1 or primary_index > #columns then
      log.err(string.format("Primary column index must be between 1 and %d", #columns))
      return
   end

   local indent = (lines[start]:match("^%s*") or "")
   local new_lines = {}
   for row_index, line in ipairs(row_lines) do
      columns = split_markdown_table_row(line)
      local marker = ordered and (row_index .. ". ") or "- "
      new_lines[#new_lines + 1] = indent .. marker .. (columns[primary_index] or "")

      local child_indent = indent .. string.rep(" ", #marker)
      for index, cell in ipairs(columns) do
         if index ~= primary_index and cell ~= "" then
            new_lines[#new_lines + 1] = child_indent .. "- " .. cell
         end
      end
   end

   vim.api.nvim_buf_set_lines(bufnr, start - 1, finish, false, new_lines)
   log.info("Converted Markdown table to list")
end

local function prompt_markdown_table_to_list(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   vim.ui.select({ "unordered", "ordered" }, { prompt = "List type:" }, function(choice)
      if not choice then
         log.info("Aborted")
         return
      end

      local start, _, separator, lines = find_markdown_table_bounds(bufnr)
      if not start then
         log.err("Cursor is not in a Markdown table")
         return
      end
      local header = split_markdown_table_row(lines[separator - 1] or "")

      vim.ui.input({ prompt = string.format("Primary column index (1-%d): ", #header), default = "1" }, function(input)
         if not input or input == "" then
            log.info("Aborted")
            return
         end

         local primary_index = tonumber(input)
         if not primary_index or primary_index % 1 ~= 0 then
            log.err("Primary column index must be a whole number")
            return
         end

         markdown_table_to_list(bufnr, choice == "ordered", primary_index)
      end)
   end)
end

local function strip_markdown_heading(line)
   local hashes, text = line:match("^%s*(#+)%s+(.-)%s*$")
   if not hashes or #hashes > 6 then
      return nil
   end

   return #hashes, text:gsub("%s+#+%s*$", "")
end

local function markdown_heading_slug(text)
   local slug = text:lower()
   slug = slug:gsub("[^%w%s%-\128-\255]", "")
   slug = trim(slug):gsub("%s+", "-")
   return slug
end

local function collect_markdown_headings(lines)
   local headings = {}
   local in_fence = false
   local fence_marker

   for lnum, line in ipairs(lines) do
      local marker = line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
      if marker and (not in_fence or marker:sub(1, 1) == fence_marker) then
         in_fence = not in_fence
         fence_marker = in_fence and marker:sub(1, 1) or nil
      elseif not in_fence then
         local level, text = strip_markdown_heading(line)
         if level and text ~= "" then
            headings[#headings + 1] = { lnum = lnum, level = level, text = text }
         end
      end
   end

   return headings
end

local function toc_insert_lnum(lines, headings)
   local content_start = 1
   local has_frontmatter = false
   if lines[1] == "---" then
      for lnum = 2, #lines do
         if lines[lnum] == "---" then
            content_start = lnum + 1
            has_frontmatter = true
            break
         end
      end
   end

   if has_frontmatter then
      while lines[content_start] == "" do
         content_start = content_start + 1
      end
   end

   if headings[1] and headings[1].level == 1 and headings[1].lnum == content_start then
      return content_start + 1, true
   end
   return content_start, false
end

local function find_existing_toc(lines)
   local start
   for lnum, line in ipairs(lines) do
      if line:match("^%s*<!%-%-toc:start%-%->%s*$") then
         start = lnum
      elseif start and line:match("^%s*<!%-%-toc:end%-%->%s*$") then
         return start, lnum
      end
   end
end

local function build_table_of_contents(lines)
   local headings = collect_markdown_headings(lines)
   if #headings == 0 then
      return nil
   end

   local min_level = headings[1].level
   for _, heading in ipairs(headings) do
      min_level = math.min(min_level, heading.level)
   end

   local slugs = {}
   local toc = { "<!--toc:start-->" }
   for _, heading in ipairs(headings) do
      local base_slug = markdown_heading_slug(heading.text)
      local slug = base_slug
      if slugs[base_slug] then
         slug = base_slug .. "-" .. slugs[base_slug]
         slugs[base_slug] = slugs[base_slug] + 1
      else
         slugs[base_slug] = 1
      end

      toc[#toc + 1] = string.rep(" ", (heading.level - min_level) * 2) .. "- [" .. heading.text .. "](#" .. slug .. ")"
   end
   toc[#toc + 1] = "<!--toc:end-->"

   return toc, headings
end

local function add_table_of_contents(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
   local toc, headings = build_table_of_contents(lines)
   if not toc then
      log.err("No Markdown headings found")
      return
   end

   local start, finish = find_existing_toc(lines)
   if start then
      vim.api.nvim_buf_set_lines(bufnr, start - 1, finish, false, toc)
      log.info("Updated table of contents")
      return
   end

   local lnum, after_heading = toc_insert_lnum(lines, headings)
   local insert = vim.list_extend(after_heading and { "" } or {}, toc)
   if lines[lnum] ~= "" then
      insert[#insert + 1] = ""
   end
   vim.api.nvim_buf_set_lines(bufnr, lnum - 1, lnum - 1, false, insert)
   log.info("Added table of contents")
end

local half_width_punctuation = {
   [","] = "，",
   ["."] = "。",
   ["?"] = "？",
   ["!"] = "！",
   [":"] = "：",
   [";"] = "；",
   ["("] = "（",
   [")"] = "）",
}

local function convert_punctuation_text(text, opts)
   opts = opts or {}
   local count = 0
   local col = 0
   local list_marker_prefix = text:match("^(%s*%d+)%.%s+")
   local list_marker_dot_col = list_marker_prefix and #list_marker_prefix + 1
   local converted = text:gsub(".", function(char)
      col = col + 1
      if opts.skip_colon and char == ":" then
         return char
      end
      if char == "." and col == list_marker_dot_col then
         return char
      end

      local replacement = half_width_punctuation[char]
      if replacement then
         count = count + 1
         return replacement
      end
      return char
   end)

   return converted, count
end

local function frontmatter_rows(lines)
   local rows = {}
   if lines[1] ~= "---" then
      return rows
   end

   for lnum = 2, #lines do
      if lines[lnum] == "---" then
         for row = 1, lnum - 2 do
            rows[row] = true
         end
         break
      end
   end

   return rows
end

local function next_byte_col(line, col)
   local byte = line:byte(col + 1)
   if not byte then
      return col
   end

   local len = 1
   if byte >= 0xF0 then
      len = 4
   elseif byte >= 0xE0 then
      len = 3
   elseif byte >= 0xC0 then
      len = 2
   end

   return math.min(col + len, #line)
end

local function visual_punctuation_range(bufnr, mode)
   local anchor = vim.fn.getpos("v")
   local cursor = vim.api.nvim_win_get_cursor(0)
   local start_row = anchor[2] - 1
   local start_col = math.max(anchor[3] - 1, 0)
   local end_row = cursor[1] - 1
   local end_col = cursor[2]

   if start_row > end_row or (start_row == end_row and start_col > end_col) then
      start_row, end_row = end_row, start_row
      start_col, end_col = end_col, start_col
   end

   if mode == "V" then
      return start_row, 0, end_row, -1
   end
   if mode == "\022" and start_col > end_col then
      start_col, end_col = end_col, start_col
   end

   local end_line = vim.api.nvim_buf_get_lines(bufnr, end_row, end_row + 1, false)[1] or ""
   return start_row, start_col, end_row, next_byte_col(end_line, end_col)
end

local function convert_half_width_punctuation(bufnr)
   bufnr = bufnr or vim.api.nvim_get_current_buf()
   local mode = vim.fn.mode()
   local count = 0

   if mode == "v" or mode == "V" or mode == "\022" then
      local start_row, start_col, end_row, end_col = visual_punctuation_range(bufnr, mode)
      local frontmatter = frontmatter_rows(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false))

      if mode == "\022" then
         local lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
         for index, line in ipairs(lines) do
            if start_col < #line then
               local row = start_row + index - 1
               local row_end_col = math.min(end_col, #line)
               local text = line:sub(start_col + 1, row_end_col)
               local converted, line_count = convert_punctuation_text(text, { skip_colon = frontmatter[row] })
               count = count + line_count
               if line_count > 0 then
                  vim.api.nvim_buf_set_text(bufnr, row, start_col, row, row_end_col, { converted })
               end
            end
         end
      else
         local lines = vim.api.nvim_buf_get_text(bufnr, start_row, start_col, end_row, end_col, {})
         for index, line in ipairs(lines) do
            local line_count
            local row = start_row + index - 1
            lines[index], line_count = convert_punctuation_text(line, { skip_colon = frontmatter[row] })
            count = count + line_count
         end
         if count > 0 then
            vim.api.nvim_buf_set_text(bufnr, start_row, start_col, end_row, end_col, lines)
         end
      end
   else
      local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
      local frontmatter = frontmatter_rows(lines)
      for index, line in ipairs(lines) do
         local line_count
         lines[index], line_count = convert_punctuation_text(line, { skip_colon = frontmatter[index - 1] })
         count = count + line_count
      end
      if count > 0 then
         vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
      end
   end

   log.info(string.format("Converted %d punctuation mark(s)", count))
end

local function process_image()
   -- TODO: after link parsing recognize embeds, check if is image
   local link = obsidian.api.cursor_link()
   if not link then
      log.err("Not on a link")
      return
   end
   local locaction = obsidian.util.parse_link(link)
   local path = obsidian.api.resolve_attachment_path(locaction)
   if not path then
      return
   end

   local choice = vim.fn.confirm("Process image:", "&Extract text\n&Describe image\n&Custom prompt", 1)
   if choice == 1 then
      run_ollama(path, "extract_text")
   elseif choice == 2 then
      run_ollama(path, "describe_image")
   elseif choice == 3 then
      vim.ui.input({ prompt = "Custom prompt: " }, function(input)
         if not input or input == "" then
            return
         end
         run_ollama(path, input)
      end)
   end
end

pcall(function()
   require("obsidian").code_action.add({
      name = "process_image",
      title = "Process image (extract text, describe, or custom)",
      fn = process_image,
   })

   require("obsidian").code_action.add({
      name = "cleanup_footnotes",
      title = "Clean up footnotes",
      fn = cleanup_footnotes,
   })

   require("obsidian").code_action.add({
      name = "markdown_table_to_list",
      title = "Convert Markdown table to list",
      fn = prompt_markdown_table_to_list,
   })

   require("obsidian").code_action.add({
      name = "add_table_of_contents",
      title = "Add table of contents",
      fn = add_table_of_contents,
   })

   require("obsidian").code_action.add({
      name = "convert_half_width_punctuation",
      title = "Convert half-width punctuation to full-width",
      fn = convert_half_width_punctuation,
   })
end)

return {
   process_image = process_image,
   cleanup_footnotes = cleanup_footnotes,
   convert_markdown_footnotes = convert_markdown_footnotes,
   markdown_table_to_list = prompt_markdown_table_to_list,
   add_table_of_contents = add_table_of_contents,
   convert_half_width_punctuation = convert_half_width_punctuation,
   capture_to_daily = capture_to_daily,
}
