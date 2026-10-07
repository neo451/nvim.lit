-- TODO: handle the clipboard image, and make a floating window to edit the text before putting
local attachment = require("obsidian.attachment")
local log = require("obsidian.log")

local function new_spinner(bufnr, row, col)
   local spinner = require("spinner")
   local id = string.format("extmark-spinner-%d-%d-%d", bufnr, row, col)
   spinner.config(id, {
      kind = "extmark",
      bufnr = bufnr, -- must be provided
      row = row, -- must be provided, which line, 0-based
      col = col, -- must be provided, which col, 0-based

      ns = vim.api.nvim_create_namespace("ext-spinner"), -- namespace, optional
      hl_group = "Spinner", -- hl_group for text, optional
   })
   return id
end

local function run_ollama(path, prompt)
   -- local cmds = { "ollama", "run", "qwen3-vl:2b", path, prompt, "--think=false" }
   local cmds = { "tesseract", path, "stdout", "-l", "chi_sim" }

   local row, col = unpack(vim.api.nvim_win_get_cursor(0))
   row = row - 1 -- 0-based

   local spinner = require("spinner")

   local ok, job_or_err = pcall(
      vim.system,
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

   if ok then
      local id = new_spinner(vim.api.nvim_get_current_buf(), row, col)
      spinner.start(id)
   else
      log.err(job_or_err)
   end
end

local function process_image()
   -- TODO: after link parsing recognize embeds, check if is image
   local link = require("obsidian.api").cursor_link()
   if not link then
      log.err("Not on a link")
      return
   end
   local ref = require("obsidian.parse.refs").parse(link)

   if not ref then
      return
   end

   local path, err = attachment._resolve(ref.target)
   if err then
      log.err(err)
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

require("obsidian").code_action.add({
   name = "process_image",
   title = "Process image (extract text, describe, or custom)",
   fn = process_image,
})
