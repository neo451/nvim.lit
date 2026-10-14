-- cppjieba is distributed as a LuaRock; expose its Lua wrapper and native
-- module without adding the rock's plugin directory (which creates global
-- word-motion mappings).
-- local rocks = vim.fs.joinpath(vim.fn.stdpath("data"), "rocks")
-- local rocks_lua = vim.fs.joinpath(rocks, "share", "lua", "5.1")
-- local rocks_lib = vim.fs.joinpath(rocks, "lib", "lua", "5.1")
-- package.path = rocks_lua .. "/?.lua;" .. rocks_lua .. "/?/init.lua;" .. package.path
-- package.cpath = rocks_lib .. "/?.so;" .. package.cpath
--
-- -- Binary rocks cannot discover libstdc++ through Nix's dynamic linker path.
-- if vim.env.NIX_LD_LIBRARY_PATH then
--    package.loadlib(vim.fs.joinpath(vim.env.NIX_LD_LIBRARY_PATH, "libstdc++.so.6"), "*")
-- end

vim.opt.rtp:append("~/Plugins/jieba.nvim")
-- Keep jieba's replacements for Vim word motions local to Markdown buffers.
-- The dictionary is initialized lazily on the first motion.
local jieba_motion = require("wordmotion.nvim.jieba")
local jieba_keymaps = {
   w = { { "n", "x" }, { true, true } },
   b = { { "n", "x" }, { true, false } },
   e = { { "n", "x" }, { false, true } },
   ge = { { "n", "x" }, { false, false } },
   iw = { { "x" }, { false } },
   aw = { { "x" }, { true } },
}

for lhs, keymap in pairs(jieba_keymaps) do
   local args = keymap[2]
   vim.keymap.set(keymap[1], lhs, function()
      jieba_motion.init()
      jieba_motion.motion:keymap(unpack(args))
   end, { buffer = true, noremap = true, desc = "Jieba word motion" })
end
