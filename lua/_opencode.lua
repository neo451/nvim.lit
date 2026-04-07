return function(prompt, callback)
   if vim.fn.executable("opencode") ~= 1 then
      vim.notify("opencode not found in PATH", vim.log.levels.ERROR, { title = "Opencode Run" })
      return
   end

   vim.system(
      { "opencode", "run", prompt },
      {},
      vim.schedule_wrap(function(result)
         if result.code ~= 0 then
            vim.notify(
               "opencode failed (exit " .. result.code .. "): " .. (result.stderr or ""),
               vim.log.levels.ERROR,
               { title = "Opencode Run" }
            )
            return
         end
         callback(result.stdout)
      end)
   )
end
