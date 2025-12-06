local Router = require("experiments.router")

local router = Router.new()

local M = {}

local state = {}

state.rendered_html = "<bold>hi</bold>"

M.open = function(port)
   vim.api.nvim_create_autocmd("FileType", {
      pattern = "markdown",
      callback = function(ev)
         local lines = vim.api.nvim_buf_get_lines(ev.buf, 0, -1, false)
         vim.system({
            "pandoc",
            "-f",
            "markdown",
            "-t",
            "html",
         }, {
            stdin = table.concat(lines, "\n"),
         }, function(out)
            if out.code ~= 0 then
               vim.notify("failed to convert")
               return
            end
            state.rendered_html = out.stdout
         end)
         -- local lines = require("tohtml").tohtml(0, {})
         -- state.rendered_html = table.concat(lines, "\n")
      end,
   })

   router:get("/", function(_, _)
      return state.rendered_html
   end)

   router:listen(port)
end

return M
