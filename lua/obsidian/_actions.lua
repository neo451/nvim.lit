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
end)

return {
   process_image = process_image,
   cleanup_footnotes = cleanup_footnotes,
   convert_markdown_footnotes = convert_markdown_footnotes,
   capture_to_daily = capture_to_daily,
}
