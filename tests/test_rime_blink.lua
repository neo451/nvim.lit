-- Run: nvim --headless -u NONE -l tests/test_rime_blink.lua
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.g.rime_enabled = true
vim.bo.filetype = "markdown"

local config
local list = { items = {}, context = nil, selected_item_idx = nil }
local cmp = {
   setup = function(opts) config = opts end,
   hide = function() end,
   get_context = function() return list.context end,
   get_items = function() return list.items end,
   get_selected_item_idx = function() return list.selected_item_idx end,
   accept = function(opts)
      local item = list.items[opts.index]
      assert(item and item.client_name == "rime_ls")
      local cursor = vim.api.nvim_win_get_cursor(0)
      local start = cursor[2] - #item.reading
      vim.api.nvim_buf_set_text(0, cursor[1] - 1, start, cursor[1] - 1, cursor[2], { item.word })
      vim.api.nvim_win_set_cursor(0, { cursor[1], start + #item.word })
      opts.callback()
      return true
   end,
}
package.loaded["blink.cmp"] = cmp
local rime = require("_blink")
local function check(actual, expected)
   assert(actual == expected, tostring(actual) .. " != " .. tostring(expected))
end
local function line(text)
   -- Headless normal mode cannot position the cursor past end-of-line.
   vim.api.nvim_buf_set_lines(0, 0, -1, false, { text .. "X" })
   vim.api.nvim_win_set_cursor(0, { 1, #text })
end
local function flush()
   vim.wait(20, function() return false end)
end
local rime_item = { client_name = "rime_ls", label = "你好", reading = "nihao", word = "你好" }
local other = { client_name = "marksman", label = "-" }
local transform = config.sources.providers.lsp.transform_items
local function items(keyword, candidates)
   return transform({ get_keyword = function() return keyword end }, candidates)
end
check(#items("-", { { client_name = "rime_ls", label = "－", insertText = "－" }, other }), 1)
check(#items("nihao", { { client_name = "rime_ls", label = "，", insertText = "，" }, rime_item }), 1)
check(#items("nihao", { rime_item }), 1)
check(#items("nihao", { { client_name = "rime_ls", label = "1. －" }, rime_item }), 1)
check(#items("-", { rime_item }), 0)

line("中文nihao")
list.items = { rime_item }
check(config.keymap["<Space>"][1](cmp), true)
check(vim.api.nvim_get_current_line(), "中文你好X")
check(rime.restore_rime(), true)
flush()
check(vim.api.nvim_get_current_line(), "中文nihaoX")
check(rime.restore_rime(), false)

line("中文nihao")
config.keymap["<Space>"][1](cmp)
vim.api.nvim_win_set_cursor(0, { 1, 0 })
check(rime.restore_rime(), false)
check(vim.api.nvim_get_current_line(), "中文你好X")

list.items = { { client_name = "dictionary", label = "hello" }, rime_item }
line("hello")
check(config.keymap["<Space>"][1](cmp), " ")
list.items = { rime_item }
line("中文nihao")
config.keymap[","][1](cmp)
flush()
check(vim.api.nvim_get_current_line(), "中文你好，X")
check(rime.restore_rime(), true)
flush()
check(vim.api.nvim_get_current_line(), "中文nihao，X")

line("中文nihao")
config.keymap["<Space>"][1](cmp)
vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, { "!" })
check(rime.restore_rime(), false)
check(vim.api.nvim_get_current_line(), "!中文你好X")

list.items = { rime_item, { client_name = "rime_ls", reading = "nihao", word = "您好" } }
line("nihao")
check(config.keymap[";"][1](cmp), true)
check(vim.api.nvim_get_current_line(), "您好X")
check(rime.restore_rime(), true)
flush()
check(vim.api.nvim_get_current_line(), "nihaoX")

list.items = { rime_item }
line("nihao")
check(config.keymap["<C-y>"][1](cmp), true)
check(rime.restore_rime(), true)
flush()
check(vim.api.nvim_get_current_line(), "nihaoX")

list.items = {}
line("中文")
check(config.keymap["."][1](cmp), "。")
check(config.keymap["("][1](cmp), "（")
check(config.keymap[")"][1](cmp), "）")
check(config.keymap['"'][1](cmp), "＂")
line("- ")
check(config.keymap["."][1](cmp), false)
line("hello")
check(config.keymap[","][1](cmp), false)
check(config.keymap["("][1](cmp), false)
check(config.keymap['"'][1](cmp), false)
vim.g.rime_enabled = false
line("中文")
check(config.keymap["."][1](cmp), false)

-- BlinkCmpShow is the public seam for automatically accepting a numbered
-- Rime candidate. Ignore stale events from a superseded completion context.
vim.g.rime_enabled = true
local numbered = { client_name = "rime_ls", label = "你好", reading = "nihao1", word = "你好" }
list.items = { numbered }
list.context = { id = 2 }
line("nihao1")
vim.api.nvim_exec_autocmds("User", {
   pattern = "BlinkCmpShow",
   data = { context = { id = 1, cursor = { 1, 6 }, line = "nihao1X" } },
})
check(vim.api.nvim_get_current_line(), "nihao1X")
vim.api.nvim_exec_autocmds("User", {
   pattern = "BlinkCmpShow",
   data = { context = { id = 2, cursor = { 1, 6 }, line = "nihao1X" } },
})
check(vim.api.nvim_get_current_line(), "你好X")

print("Rime/Blink checks passed")
