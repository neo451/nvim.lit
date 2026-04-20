local miniclue = require("mini.clue")

miniclue.setup({
   -- Define which clues to show. By default shows only clues for custom mappings
   -- (uses `desc` field from the mapping; takes precedence over custom clue).
   clues = {
      -- _G.Config.leader_group_clues,
      {
         { mode = "n", keys = "<Leader>b", desc = "+Buffer" },
         { mode = "n", keys = "<Leader>e", desc = "+Explore/Edit" },
         { mode = "n", keys = "<Leader>f", desc = "+Find" },
         { mode = "n", keys = "<Leader>t", desc = "+Terminal" },
         { mode = "n", keys = "<Leader>g", desc = "+Git" },
         { mode = "n", keys = "<Leader>u", desc = "+UI" },
         { mode = "n", keys = "<Leader>o", desc = "+Obsidian" },
         { mode = "n", keys = "<Leader><Leader>", desc = "+Other" },
      },
      miniclue.gen_clues.builtin_completion(),
      miniclue.gen_clues.g(),
      miniclue.gen_clues.marks(),
      miniclue.gen_clues.registers(),
      miniclue.gen_clues.z(),
   },
   window = {
      config = {
         width = 50,
      },
   },
   -- Explicitly opt-in for set of common keys to trigger clue window
   triggers = {
      { mode = "n", keys = "<Leader>" }, -- Leader triggers
      { mode = "x", keys = "<Leader>" },
      { mode = "n", keys = "\\" }, -- mini.basics
      { mode = "n", keys = "[" }, -- mini.bracketed
      { mode = "n", keys = "]" },
      { mode = "x", keys = "[" },
      { mode = "x", keys = "]" },
      { mode = "i", keys = "<C-x>" }, -- Built-in completion
      { mode = "n", keys = "g" }, -- `g` key
      { mode = "x", keys = "g" },
      { mode = "n", keys = "'" }, -- Marks
      { mode = "n", keys = "`" },
      { mode = "x", keys = "'" },
      { mode = "x", keys = "`" },
      { mode = "n", keys = '"' }, -- Registers
      { mode = "x", keys = '"' },
      { mode = "i", keys = "<C-r>" },
      { mode = "c", keys = "<C-r>" },
      { mode = "n", keys = "<C-w>" }, -- Window commands
      { mode = "n", keys = "z" }, -- `z` key
      { mode = "x", keys = "z" },
   },
})
require("mini.ai").setup({})
require("mini.diff").setup({})
require("mini.git").setup({})
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()
require("mini.surround").setup({})
require("mini.test").setup({})
require("mini.pick").setup({})
require("mini.extra").setup({})
require("mini.hipatterns").setup({
   highlighters = {
      fixme = { pattern = " FIXME:", group = "MiniHipatternsFixme" },
      hack = { pattern = " HACK:", group = "MiniHipatternsHack" },
      todo = { pattern = " TODO:", group = "MiniHipatternsTodo" },
      note = { pattern = " NOTE:", group = "MiniHipatternsNote" },
   },
})
