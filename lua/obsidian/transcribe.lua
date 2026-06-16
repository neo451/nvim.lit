local function whisper(ctx)
   local key = vim.env.OPENAI_API_KEY
   if not key or key == "" then
      vim.notify("OPENAI_API_KEY is not set", vim.log.levels.ERROR)
      return
   end

   vim.ui.select({
      { label = "Auto detect", value = nil },
      { label = "English", value = "en" },
      { label = "Chinese (Simplified)", value = "zh" },
   }, {
      prompt = "Whisper language:",
      format_item = function(item)
         return item.label
      end,
   }, function(choice)
      if not choice then
         return
      end

      local args = {
         "curl",
         "-sS",
         "https://api.openai.com/v1/audio/transcriptions",
         "-H",
         "Authorization: Bearer " .. key,
         "-F",
         "model=whisper-1",
         "-F",
         "file=@" .. ctx.path,
      }

      if choice.value then
         vim.list_extend(args, { "-F", "language=" .. choice.value })
      end

      vim.system(args, { text = true }, function(obj)
         vim.schedule(function()
            if obj.code ~= 0 then
               vim.notify(obj.stderr or obj.stdout, vim.log.levels.ERROR)
               return
            end

            local ok, decoded = pcall(vim.json.decode, obj.stdout)
            if not ok or not decoded.text then
               vim.notify("Failed to parse Whisper response", vim.log.levels.ERROR)
               return
            end

            vim.api.nvim_buf_set_lines(ctx.bufnr, -1, -1, false, {
               "",
               "## Transcript",
               "",
               decoded.text,
            })
         end)
      end)
   end)
end

return {
   whisper = whisper,
}
