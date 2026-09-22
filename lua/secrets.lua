local M = {}

M.get = function(name)
   local dir = vim.fs.joinpath(vim.fn.stdpath("config"), "secrets")
   local fname = vim.fs.joinpath(dir, name)
   if vim.uv.fs_stat(fname) then
      return vim.fn.readfile(fname)[1]
   else
      vim.notify("secret: " .. name .. " don't exist on this machine")
   end
end

return M
