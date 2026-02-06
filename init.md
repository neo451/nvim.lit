---
id: nvim
count: 29
tags: []
---

- [[vim]]
- [[archived]]
- [[tey]]
- [[lib]]

## juansalvatore/git-dashboard-nvim

## Vim Enhancement

### stevearc/quicker.nvim!

- ft: `qf`

### monaqa/dial.nvim

- keys: `{ "<C-a>", "<C-x>", "g<C-a>", "g<C-x>" }`

```lua
local augend = require("dial.augend")

require("dial.config").augends:register_group({
   default = {
      augend.date.alias["%Y/%m/%d"], -- date (2022/02/19, etc.)
      augend.date.alias["%m/%d/%Y"], -- date (02/19/2022, etc.)
      augend.constant.alias.bool, -- boolean value (true <-> false)
   },
})

vim.keymap.set("n", "<C-a>", function()
   require("dial.map").manipulate("increment", "normal")
end)
vim.keymap.set("n", "<C-x>", function()
   require("dial.map").manipulate("decrement", "normal")
end)
vim.keymap.set("v", "g<C-a>", function()
   require("dial.map").manipulate("increment", "gvisual")
end)
vim.keymap.set("v", "g<C-x>", function()
   require("dial.map").manipulate("decrement", "gvisual")
end)
```

### andrewferrier/debugprint.nvim!

- keys: `g?v`
- cmd: `Debugprint`

- `g?p`/`g?P`
- `g?v`
- `Debugprint qflist`

## Git

### noamsto/resolved.nvim!

### NeogitOrg/neogit

- keys: `<leader>gg`
- cmd: `Neogit`

```lua
require("neogit").setup({})
vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>")
```

## Files

### stevearc/oil.nvim

```lua
require("oil").setup({
   skip_confirm_for_simple_edits = true,
   win_options = {
      signcolumn = "yes:2",
   },
   view_options = {
      show_hidden = true,
   },
})
vim.keymap.set("n", "-", "<cmd>Oil<cr>")

vim.keymap.set("n", "_", function()
   local dir = tostring(Obsidian.workspace.root):gsub(" ", "\\ ")
   return "<cmd>Oil " .. dir .. "<cr>"
end, { expr = true })
```

## UI

### folke/tokyonight.nvim

```lua
vim.cmd.colorscheme("tokyonight")
```

### j-hui/fidget.nvim!

- event: `LspAttach`

### shortcuts/no-neck-pain.nvim

- keys: `<leader><leader>z`

### folke/todo-comments.nvim

```lua
require("todo-comments").setup({})
```

### mcauley-penney/visual-whitespace.nvim!

- event: `ModeChanged *:[vV\22]`

### MeanderingProgrammer/treesitter-modules.nvim

```lua
require("treesitter-modules").setup({
   incremental_selection = {
      enable = true,
      keymaps = {
         init_selection = "<A-o>",
         node_incremental = "<A-o>",
         scope_incremental = "<A-O>",
         node_decremental = "<A-i>",
      },
   },
})
```

### mistweaverco/kulala.nvim

- ft: `{ "http", "rest" }`
- keys: `{ "<leader>Rs", "<leader>Ra", "<leader>Rb" }`

```lua
require("kulala").setup({
   global_keymaps = true,
})
```

## Bib

### krissen/blink-cmp-bibtex

- ft: `markdown`

```lua
require("blink-cmp-bibtex").setup({
   filetypes = { "markdown" },
   files = { vim.fn.expand("$REF") },
})
```

### krissen/snacks-bibtex.nvim

- ft: `markdown`

```lua
require("snacks-bibtex").setup({
   global_files = {
      vim.fn.expand("$REF"),
   },
})
vim.keymap.set("n", "<leader>bc", function()
   require("snacks-bibtex").bibtex()
end, {
   desc = "BibTeX citations (Snacks)",
})
```

## Markdown

### YousefHadder/markdown-plus.nvim

- ft: `markdown`

```lua
require("markdown-plus").setup({})
```

### OXY2DEV/markview.nvim

### bngarren/checkmate.nvim!

- ft: `markdown`

works for `todo.md` `TODO.md`

### hamidi-dev/org-list.nvim

- ft: `markdown`

### numEricL/table.vim

## LSP

### rachartier/tiny-code-action.nvim!

- event: `LspAttach`

### rachartier/tiny-inline-diagnostic.nvim

```lua
require("tiny-inline-diagnostic").setup()
vim.diagnostic.config({ virtual_text = false })
```

## Completion

### rafamadriz/friendly-snippets

### archie-judd/blink-cmp-words

### saghen/blink.cmp

- event: `{ "InsertEnter", "CmdlineEnter" }`
- version: `1.*`

```lua
require("blink.cmp").setup({
   keymap = {
      preset = "default",
      ["<C-b>"] = { "scroll_documentation_up" },
      ["<C-f>"] = { "scroll_documentation_down" },
      [";"] = {
         function(cmp)
            if not vim.g.rime_enabled then
               return false
            end
            local rime_item_index = require("rime").get_n_rime_item_index(1)
            if #rime_item_index ~= 1 then
               return false
            end
            -- If you want to select more than once,
            -- just update this cmp.accept with vim.api.nvim_feedkeys('1', 'n', true)
            -- The rest can be updated similarly
            return cmp.accept({ index = rime_item_index[1] })
         end,
         "fallback",
      },
   },
   completion = {
      menu = {
         draw = {
            columns = {
               { "label", "label_description", gap = 3 },
               { "kind" },
            },
         },
      },
      documentation = { auto_show = true },
   },

   sources = {
      default = {
         "lsp",
         "path",
         "snippets",
         "buffer",
         "bibtex",
      },
      per_filetype = {
         markdown = { "bibtex", "obsidian", "dictionary" },
      },
      providers = {
         bibtex = {
            module = "blink-cmp-bibtex",
            name = "BibTeX",
            min_keyword_length = 2,
            score_offset = 10,
            async = true,
            opts = {},
            -- provider-level overrides (optional)
         },
         -- Use the thesaurus source
         thesaurus = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.thesaurus",
            -- All available options
            opts = {
               -- A score offset applied to returned items.
               -- By default the highest score is 0 (item 1 has a score of -1, item 2 of -2 etc..).
               score_offset = 0,

               -- Default pointers define the lexical relations listed under each definition,
               -- see Pointer Symbols below.
               -- Default is as below ("antonyms", "similar to" and "also see").
               definition_pointers = { "!", "&", "^" },

               -- The pointers that are considered similar words when using the thesaurus,
               -- see Pointer Symbols below.
               -- Default is as below ("similar to", "also see" }
               similarity_pointers = { "&", "^" },

               -- The depth of similar words to recurse when collecting synonyms. 1 is similar words,
               -- 2 is similar words of similar words, etc. Increasing this may slow results.
               similarity_depth = 2,
            },
         },

         -- Use the dictionary source
         dictionary = {
            name = "blink-cmp-words",
            module = "blink-cmp-words.dictionary",
            -- All available options
            opts = {
               -- The number of characters required to trigger completion.
               -- Set this higher if completion is slow, 3 is default.
               dictionary_search_threshold = 3,

               -- See above
               score_offset = 0,

               -- See above
               definition_pointers = { "!", "&", "^" },
            },
         },
      },
   },
})
```

## nvim-mini/mini.nvim

vip followed by gh / gH applies/resets hunks inside current paragraph. Same can be achieved in operator form ghip / gHip, which has the advantage of being dot-repeatable.
gh* / gH* applies/resets current line (even if it is not a full hunk).
ghgh / gHgh applies/resets hunk range under cursor.
dgh deletes hunk range under cursor.
`[H` / `[h` / `]h` / `]H` navigate cursor to the first / previous / next / last hunk range of the current buffer.

```lua
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
require("mini.icons").setup()
MiniIcons.mock_nvim_web_devicons()
require("mini.surround").setup({})
require("mini.test").setup({})
require("mini.cmdline").setup({
   autocomplete = { enable = false },
})
```

## folke/snacks.nvim

```lua
require("snacks").setup({
   gitbrowse = { enabled = true },
   scroll = { enabled = true },
   image = {
      enabled = vim.fn.executable("convert") == 1,
      resolve = function(path, src)
         local api = require("obsidian.api")
         if api.path_is_note(path) then
            return api.resolve_attachment_path(src)
         end
      end,
      wo = { winhighlight = "FloatBorder:WhichKeyBorder" },
      doc = {
         inline = false,
         max_width = 45,
         max_height = 20,
      },
   },
   input = { enabled = true },
   picker = { enabled = true },
   statuscolumn = { enabled = true },
   styles = {
      notification = {
         wo = { wrap = true },
      },
      snacks_image = { relative = "editor", col = -1 },
   },
   notifier = {
      enabled = true,
      timeout = 3000,
   },
})
```

## esmuellert/vscode-diff.nvim

- cmd: `CodeDiff`

## stevearc/conform.nvim

```lua
require("conform").setup({
   format_on_save = {
      timeout_ms = 500,
      lsp_format = "fallback",
   },
   formatters_by_ft = {
      nix = { "alejandra" },
      lua = { "stylua" },
      markdown = { "prettier", "injected" },
      quarto = { "prettier" },
      qml = { "qmlformat" },
   },
})
```
