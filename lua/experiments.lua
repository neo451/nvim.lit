require("qol.search")

---Refer to <https://microsoft.github.io/language-server-protocol/specification/#snippet_syntax>

---for the specification of valid body.

---@param trigger string trigger string for snippet
---@param body string | fun(): string snippet text that will be expanded
---@param opts? vim.keymap.set.Opts
function _G.Config.snippet_add(trigger, body, opts)
   vim.keymap.set("ia", trigger, function()
      -- If abbrev is expanded with keys like "(", ")", "<cr>", "<space>",
      -- don't expand the snippet. Only accept "<c-]>" as trigger key.
      local c = vim.fn.nr2char(vim.fn.getchar(0))

      if c ~= "" then
         vim.api.nvim_feedkeys(trigger .. c, "i", true)
         return
      end
      if type(body) == "function" then
         body = body()
      end
      vim.snippet.expand(body)
   end, opts)
end

vim.filetype.add({
   extension = {
      base = "yaml",
   },
})

vim.api.nvim_create_user_command("Sort", function(opts)
   if not tonumber(opts.args) then
      print("Error: Argument must be a number")
      return
   end
   local bang = opts.bang and "!" or ""
   local range = opts.range == 0 and "" or ("%d,%d"):format(opts.line1, opts.line2)
   local pattern = string.format("%ssort%s /^\\([^|]*|\\)\\{%s\\}/", range, bang, opts.args)
   vim.cmd(pattern)
end, { nargs = 1, bang = true, range = true })

vim.api.nvim_create_user_command("Mkspell", function(opts)
   vim.cmd("mkspell! " .. vim.o.spellfile)
end, {})

vim.api.nvim_create_user_command("Lsp", "checkhealth vim.lsp", {})

require("vim._extui").enable({})
require("ui.statusline")
require("ui.tabline")
require("ui.argpoon").setup({})
-- require("diy.fuzzy").enable(false)

-- require("ob_git").setup({
--    pull_on_startup = false,
-- })
require("babel").enable(true)

-- require("quickfix")
