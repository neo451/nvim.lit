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
end)

return {
   process_image = process_image,
   capture_to_daily = capture_to_daily,
}
