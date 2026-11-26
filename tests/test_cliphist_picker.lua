-- Run: nvim --headless -u NONE -l tests/test_cliphist_picker.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
local original_system = vim.system
local calls = {}
local copied
local bytes = "  line one\nline two\0\n"

vim.system = function(cmd, opts, callback)
   calls[#calls + 1] = { cmd = cmd, opts = opts }
   local result
   if cmd[1] == "cliphist" and cmd[2] == "list" then
      result = { code = 0, stdout = "23\tline one line two\n24\t[[ binary data ]]\n" }
   elseif cmd[1] == "cliphist" and cmd[2] == "decode" then
      assert(cmd[3] == "23")
      result = { code = 0, stdout = bytes }
   elseif cmd[1] == "wl-copy" then
      copied = opts.stdin
      result = { code = 0 }
   else
      error(vim.inspect(cmd))
   end
   vim.schedule(function()
      callback(result)
   end)
end

package.loaded["obsidian.picker"] = {
   get = function(name)
      assert(name == "snacks.picker")
      return {
         select = function(items, opts, on_choice)
            assert(#items == 2 and items[1].id == "23")
            assert(opts.format_item(items[2]) == "[[ binary data ]]")
            on_choice({ items[1] })
            return { opts = {} }
         end,
      }
   end,
}

require("cliphist_picker").open()
assert(
   vim.wait(2000, function()
      return copied ~= nil
   end),
   "picker did not restore clipboard"
)
assert(copied == bytes, "decoded bytes were changed")
assert(#calls == 3 and #calls[1].cmd == 2 and #calls[3].cmd == 1)
vim.system = original_system
print("cliphist picker: ok")
