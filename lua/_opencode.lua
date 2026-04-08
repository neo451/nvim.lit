--- TODO: model

return function(prompt, flags, callback)
   if vim.fn.executable("opencode") ~= 1 then
      vim.notify("opencode not found in PATH", vim.log.levels.ERROR, { title = "Opencode Run" })
      return
   end

   local args = { "opencode", "run", prompt }

   for flag, value in pairs(flags or {}) do
      table.insert(args, "--" .. flag)
      if value ~= true then
         if type(value) == "table" then
            for _, v in ipairs(value) do
               table.insert(args, tostring(v))
            end
         else
            table.insert(args, tostring(value))
         end
      end
   end

   vim.system(
      args,
      {},
      vim.schedule_wrap(function(result)
         vim.print(result)
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
